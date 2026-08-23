# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
"""Stitch per-region .bin files into one flat 8 MiB chip image.

Each region's bytes land at file offset ``chip_addr * 2`` (Binary Ninja's C28x
plugin convention: ``BN_byte = 2 * chip_word``); gaps stay 0xFF, matching erased
flash. The result loads in Binary Ninja like flash.bin does, but at base address
0, so cross-region xrefs (flash -> SARAM ramfuncs, flash -> M0 stubs, flash ->
bootrom) resolve inside a single view.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

from .regions import CHIP_BYTES, ERASED_BYTE, STITCH_REGIONS

OUTPUT_NAME = "chip_image.bin"


def resolve_flash(dump_dir: Path) -> Path | None:
    """Locate the flash capture, which operators rename per variant.

    dump writes ``flash.bin``; committed captures are often ``g103-flash.bin``
    and friends. ``flash_*`` is excluded so per-sector splits are not mistaken
    for the whole-region dump.
    """
    default = dump_dir / "flash.bin"
    if default.is_file():
        return default
    matches = sorted(
        p
        for p in dump_dir.glob("*flash*.bin")
        if p.is_file() and not p.name.startswith("flash_")
    )
    return matches[0] if matches else None


def stitch(dump_dir: Path) -> Path:
    """Write ``<dump_dir>/chip_image.bin``. Returns the output path."""
    if not dump_dir.is_dir():
        raise SystemExit(f"error: not a directory: {dump_dir}")

    image = bytearray([ERASED_BYTE]) * CHIP_BYTES

    print(f"stitch: {dump_dir}")
    out = dump_dir / OUTPUT_NAME
    print(f"output:        {out}")

    spliced = 0
    skipped: list[str] = []
    for region in STITCH_REGIONS:
        path = dump_dir / region.bin_name
        if region.bin_name == "flash.bin" and not path.is_file():
            resolved = resolve_flash(dump_dir)
            if resolved is None:
                skipped.append(region.bin_name)
                continue
            path = resolved
        if not path.is_file():
            skipped.append(region.bin_name)
            continue

        data = path.read_bytes()
        off = region.chip_addr * 2
        end = off + len(data)
        if end > CHIP_BYTES:
            raise SystemExit(
                f"error: {path.name} at chip 0x{region.chip_addr:06x} "
                f"overruns the {CHIP_BYTES}-byte image"
            )
        image[off:end] = data
        print(
            f"  {path.name:<22} chip 0x{region.chip_addr:06x} "
            f"-> byte 0x{off:06x}  ({len(data)} B)"
        )
        spliced += 1

    if spliced == 0:
        raise SystemExit(f"error: no region .bin files found under {dump_dir}")

    out.write_bytes(image)

    actual = out.stat().st_size
    sha = hashlib.sha256(image).hexdigest()
    print()
    print(f"spliced regions: {spliced}")
    if skipped:
        print(f"skipped (not in dump-dir): {' '.join(skipped)}")
    print(f"file size:       {actual} bytes ({CHIP_BYTES} expected)")
    print(f"sha256:          {sha}")

    if actual != CHIP_BYTES:
        raise SystemExit("error: output file size mismatch")
    return out
