# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
"""Two-pass memory dump of a TMS320F28335 via TI UniFlash + XDS200.

  pass 1 - halt-only        -> <outdir>/dump-halt/
  pass 2 - reset, then halt -> <outdir>/dump-reset/

Each region read is its own dslite invocation (connect, halt, read,
disconnect). The reset pass issues a CPU reset via `dslite flash --reset` before
the read loop; the device may run for a few hundred ms between reads, so RAM
regions reflect "shortly after reset" rather than a perfectly-frozen reset
state. Flash/OTP/Boot ROM are non-volatile and unaffected.
"""

from __future__ import annotations

import shutil
import subprocess
import time
from pathlib import Path

from .regions import DUMP_REGIONS

DEFAULT_CCXML = Path(__file__).parent / "data" / "f28335_xds200.ccxml"


def _dslite_running() -> str | None:
    """Return the offending process list if a DSLite already holds the probe."""
    try:
        found = subprocess.run(
            ["pgrep", "-af", "DSLite"], capture_output=True, text=True, check=False
        )
    except FileNotFoundError:
        return None
    return found.stdout.strip() or None


def dump_one(out_dir: Path, region, ccxml: Path) -> bool:
    """Capture one region. Returns True on success."""
    out = out_dir / f"{region.name}.bin"
    log = out_dir / f"{region.name}.log"
    rng = f"{region.addr_hex}@{region.page},{region.length_hex}"
    print(f"  {region.name:<18}  range={rng}")
    with log.open("wb") as fh:
        rc = subprocess.run(
            [
                "dslite",
                "--mode",
                "memory",
                f"--config={ccxml}",
                f"--range={rng}",
                "--size=16",
                f"--output={out}",
                "--verbose",
            ],
            stdout=fh,
            stderr=subprocess.STDOUT,
            check=False,
        ).returncode
    if rc == 0:
        print(f"    ok ({out.stat().st_size} bytes)")
        return True
    print(f"    FAILED (exit {rc}) - see {log}")
    return False


def run_pass(out_dir: Path, ccxml: Path) -> int:
    """Capture every region into out_dir. Returns the failure count."""
    out_dir.mkdir(parents=True, exist_ok=True)
    return sum(0 if dump_one(out_dir, r, ccxml) else 1 for r in DUMP_REGIONS)


def dump(
    outdir: Path | None = None,
    ccxml: Path = DEFAULT_CCXML,
    reset_op: int = 0,
    reconstruct: bool = True,
    stitch: bool = True,
) -> None:
    if not ccxml.is_file():
        raise SystemExit(f"error: ccxml not found: {ccxml}")
    if shutil.which("dslite") is None:
        raise SystemExit(
            "error: 'dslite' not on PATH (enable features.development.uniflash)"
        )
    running = _dslite_running()
    if running:
        raise SystemExit(
            "warning: another DSLite process is running and will hold the XDS probe:\n"
            f"{running}\n"
            "kill it before continuing (e.g. 'pkill -x DSLite'); aborting."
        )

    if outdir is None:
        # Local wall clock, as the shell's `date +%Y%m%d-%H%M%S` produced.
        outdir = Path.cwd() / "dumps" / time.strftime("%Y%m%d-%H%M%S")
    outdir.mkdir(parents=True, exist_ok=True)
    print(f"ccxml:     {ccxml}")
    print(f"dump root: {outdir}")

    print()
    print(f"=== pass 1: halt -> {outdir}/dump-halt ===")
    halt_fail = run_pass(outdir / "dump-halt", ccxml)

    print()
    print(f"=== issuing CPU reset via 'dslite flash --reset={reset_op}' ===")
    # An index, not a name: the dslite wrapper re-splits space-containing
    # arguments like "CPU Reset" into stray flash operands.
    reset_log = outdir / "reset.log"
    with reset_log.open("wb") as fh:
        rc = subprocess.run(
            [
                "dslite",
                "--mode",
                "flash",
                f"--config={ccxml}",
                f"--reset={reset_op}",
                "--verbose",
            ],
            stdout=fh,
            stderr=subprocess.STDOUT,
            check=False,
        ).returncode
    if rc == 0:
        print("reset complete")
    else:
        print(f"warning: reset command failed (exit {rc}); see {reset_log}")
        print(f"tip: run 'dslite flash --config={ccxml} --list-resets' with the target")
        print("connected to enumerate reset operations, then set --reset-op.")

    print()
    print(f"=== pass 2: reset -> {outdir}/dump-reset ===")
    reset_fail = run_pass(outdir / "dump-reset", ccxml)

    print()
    if halt_fail or reset_fail:
        raise SystemExit(
            f"done with failures: halt={halt_fail} reset={reset_fail}; inspect *.log"
        )
    print(f"done. both passes dumped under {outdir}")

    reset_dir = outdir / "dump-reset"
    # Only the reset pass is reconstructed: the halt-pass image diverges from
    # chip state because the DSS halt perturbs some peripheral registers.
    if reconstruct:
        from .reconstruct import reconstruct as do_reconstruct

        print()
        print(f"=== reconstruct: {reset_dir} ===")
        do_reconstruct(reset_dir)
        print("reconstruct: ok")

    if stitch:
        from .stitch import stitch as do_stitch

        print()
        print(f"=== stitch: {reset_dir} ===")
        do_stitch(reset_dir)
        print("stitch: ok")
