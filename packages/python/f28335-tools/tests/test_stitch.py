# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
"""Chip-image assembly: placement, fill and the flash-rename fallback."""

import pytest
from f28335_tools.regions import CHIP_BYTES, ERASED_BYTE, STITCH_REGIONS
from f28335_tools.stitch import resolve_flash, stitch


def test_region_lands_at_double_its_chip_address(tmp_path):
    (tmp_path / "bootrom.bin").write_bytes(b"\x11\x22")
    out = stitch(tmp_path)
    data = out.read_bytes()
    off = 0x3FE000 * 2
    assert data[off : off + 2] == b"\x11\x22"


def test_gaps_are_erased_flash_and_size_is_exact(tmp_path):
    (tmp_path / "bootrom.bin").write_bytes(b"\x11\x22")
    data = stitch(tmp_path).read_bytes()
    assert len(data) == CHIP_BYTES
    assert data[0] == ERASED_BYTE
    assert data[-1] == ERASED_BYTE


def test_no_regions_is_an_error(tmp_path):
    with pytest.raises(SystemExit):
        stitch(tmp_path)


def test_missing_dump_dir_is_a_clean_error(tmp_path):
    with pytest.raises(SystemExit):
        stitch(tmp_path / "nope")


def test_renamed_flash_variant_is_resolved(tmp_path):
    (tmp_path / "g103-flash.bin").write_bytes(b"\xde\xad")
    assert resolve_flash(tmp_path).name == "g103-flash.bin"


def test_plain_flash_wins_over_a_renamed_variant(tmp_path):
    (tmp_path / "g103-flash.bin").write_bytes(b"\x00\x00")
    (tmp_path / "flash.bin").write_bytes(b"\xbe\xef")
    assert resolve_flash(tmp_path).name == "flash.bin"


def test_sector_splits_are_not_mistaken_for_the_whole_region(tmp_path):
    (tmp_path / "flash_a.bin").write_bytes(b"\x00\x00")
    assert resolve_flash(tmp_path) is None


def test_csm_pwl_is_stitched_but_not_linked():
    from f28335_tools.regions import LINK_REGIONS

    assert any(r.bin_name == "csm_pwl.bin" for r in STITCH_REGIONS)
    assert not any(r.bin_name == "csm_pwl.bin" for r in LINK_REGIONS)
