# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
"""Rebuild a dump into a linkable COFF image plus disassembly.

Reads each <region>.bin under <dump-dir>, emits a matching <region>.asm under
<dump-dir>/reconstruct/, then drives cl2000 (single-shot --run_linker) to
produce <dump-dir>/link/dumped.{out,map} and dis2000 to produce
<dump-dir>/dis/dumped.dis. Finally verifies byte fidelity and writes the
classification manifest.
"""

from __future__ import annotations

import contextlib
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from . import classify, verify
from .asmcodec import encode_asm
from .regions import LINK_REGIONS
from .stitch import resolve_flash


class _Tee:
    """Write to a stream and a log file at once.

    Stands in for the shell's `exec > >(tee -a "$LOG") 2>&1`: every reconstruct
    run leaves a full transcript under <dump-dir>/log/.
    """

    def __init__(self, stream, handle):
        self._stream = stream
        self._handle = handle

    def write(self, text: str) -> int:
        self._handle.write(text)
        return self._stream.write(text)

    def flush(self) -> None:
        self._handle.flush()
        self._stream.flush()

    def __getattr__(self, name):
        return getattr(self._stream, name)


@contextlib.contextmanager
def _tee_to(log_path: Path):
    with log_path.open("a", encoding="utf-8") as handle:
        tee_out = _Tee(sys.stdout, handle)
        tee_err = _Tee(sys.stderr, handle)
        with (
            contextlib.redirect_stdout(tee_out),
            contextlib.redirect_stderr(tee_err),
        ):
            yield


BUILD_CMD_HEADER = """\
/* ============================================================
 * build.cmd  --  f28335-dump reconstruct stage
 *
 * Auto-generated linker command file for the reconstructed F28335
 * memory image. Feed this to cl2000 -z alongside the per-region
 * .asm files to produce a COFF object that dis2000 can decode.
 *
 * MEMORY block mirrors the dumped regions; PAGE 0 = program,
 * PAGE 1 = data (TI linker convention).
 *
 * csm_pwl is intentionally omitted because it lives inside .flash
 * (chip 0x33FFF8..0x33FFFF) and would overlap.
 * ============================================================ */

MEMORY
{
    PAGE 0:    /* program memory */
"""


def write_build_cmd(path: Path, included: list) -> None:
    """Emit the linker MEMORY/SECTIONS file for the regions actually present."""
    lines = [BUILD_CMD_HEADER]
    for r in (x for x in included if x.page == 0):
        lines.append(
            f"        {r.region:<14} : origin = 0x{r.origin:06x}, "
            f"length = 0x{r.length_words:04x}\n"
        )
    lines.append("\n    PAGE 1:    /* data memory */\n")
    for r in (x for x in included if x.page == 1):
        lines.append(
            f"        {r.region:<14} : origin = 0x{r.origin:06x}, "
            f"length = 0x{r.length_words:04x}\n"
        )
    lines.append("}\n\nSECTIONS\n{\n")
    for r in included:
        lines.append(f"    .{r.section:<20} : > {r.region:<14} PAGE = {r.page}\n")
    lines.append("}\n")
    path.write_text("".join(lines))


def reconstruct(dump_dir: Path) -> None:
    """Run the pipeline, teeing the transcript into <dump-dir>/log/."""
    if not dump_dir.is_dir():
        raise SystemExit(f"error: not a directory: {dump_dir}")

    log_dir = dump_dir / "log"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / f"{time.strftime('%Y%m%d-%H%M%S')}-reconstruct.log"
    with _tee_to(log_path):
        _reconstruct(dump_dir, log_path)


def _reconstruct(dump_dir: Path, log_path: Path) -> None:
    recon_dir = dump_dir / "reconstruct"
    link_dir = dump_dir / "link"
    dis_dir = dump_dir / "dis"
    for d in (recon_dir, link_dir, dis_dir, dump_dir / "log"):
        d.mkdir(parents=True, exist_ok=True)

    print(f"reconstruct: {dump_dir}")
    print(f"started: {datetime.now(timezone.utc).astimezone().isoformat()}")
    print()

    print("=== encoding .asm files ===")
    included: list = []
    asm_inputs: list[Path] = []
    missing: list[str] = []
    for r in LINK_REGIONS:
        if r.bin_name == "flash.bin":
            src = resolve_flash(dump_dir)
            if src is None:
                print(f"  SKIP flash (no flash*.bin in {dump_dir})")
                missing.append(r.bin_name)
                continue
        else:
            src = dump_dir / r.bin_name
            if not src.is_file():
                print(f"  SKIP {r.bin_name} (not in {dump_dir})")
                missing.append(r.bin_name)
                continue
        asm = recon_dir / f"{r.section}.asm"
        print(f"  {src.name:<22} -> {r.section}.asm")
        encode_asm(src, asm, r.section, r.origin, r.page)
        asm_inputs.append(asm)
        included.append(r)

    if not asm_inputs:
        raise SystemExit(f"error: no region .bin files found under {dump_dir}")

    print()
    print("=== writing build.cmd ===")
    build_cmd = recon_dir / "build.cmd"
    write_build_cmd(build_cmd, included)
    print(f"  {build_cmd}  ({len(build_cmd.read_text().splitlines())} lines)")

    print()
    print("=== linking (cl2000 --run_linker) ===")
    out_file = link_dir / "dumped.out"
    map_file = link_dir / "dumped.map"
    subprocess.run(
        [
            "cl2000",
            "-v28",
            "-ml",
            "-mt",
            "--float_support=fpu32",
            "--define=__TMS320F28335__",
            "--abi=coffabi",
            *[str(p) for p in asm_inputs],
            "-z",
            f"--output_file={out_file}",
            f"--map_file={map_file}",
            str(build_cmd),
        ],
        check=True,
    )
    print(f"  {out_file}  ({out_file.stat().st_size} bytes)")
    print(f"  {map_file}  ({len(map_file.read_text().splitlines())} lines)")

    print()
    print("=== disassembling (dis2000 --data_as_text --all) ===")
    # '--data_as_text' is required. A reconstructed COFF built from .word data is
    # all STYP_DATA -- TI only marks STYP_TEXT from assembled instructions, never
    # from .word (fixture-verified), and re-emitting decoded mnemonics would break
    # byte fidelity. Code/data structure lives in the JSON manifest below.
    dis_file = dis_dir / "dumped.dis"
    with dis_file.open("wb") as fh:
        subprocess.run(
            ["dis2000", "--data_as_text", "--all", str(out_file)],
            stdout=fh,
            check=True,
        )
    text = dis_file.read_text(errors="replace")
    print(
        f"  {dis_file}  ({len(text.splitlines())} lines, {dis_file.stat().st_size} bytes)"
    )

    print()
    print("=== byte-fidelity check (derived COFF vs raw dump) ===")
    # flash.bin is the immutable device extraction; the derived dumped.out MUST
    # hold byte-identical region bytes or the .dis/CRC tooling is untrustworthy.
    if verify.verify_roundtrip(dump_dir) != 0:
        raise SystemExit("error: reconstructed COFF is NOT byte-identical to the dump")

    print()
    print("=== classification manifest (code/data + function entries) ===")
    # Best-effort by design: a decode failure must not sink a good reconstruction.
    analysis_file = dis_dir / "dumped.analysis.json"
    try:
        classify.classify(dump_dir, analysis_file)
    except Exception as exc:
        print(f"  (classification unavailable -- manifest not written: {exc})")
    else:
        print(f"  {analysis_file}  ({analysis_file.stat().st_size} bytes)")

    print()
    print("=== summary ===")
    print(f"  regions encoded:  {len(asm_inputs)}")
    print(
        f"  regions skipped:  {len(missing)}"
        + (f" ({' '.join(missing)})" if missing else "")
    )
    print(f"done: {datetime.now(timezone.utc).astimezone().isoformat()}")
