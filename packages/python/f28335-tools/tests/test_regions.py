# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
"""Guard the region tables: a wrong address is a silently corrupt dump."""

from f28335_tools.regions import CHIP_BYTES, DUMP_REGIONS, LINK_REGIONS, STITCH_REGIONS


def test_expected_row_counts():
    assert len(DUMP_REGIONS) == 24
    assert len(LINK_REGIONS) == 23  # csm_pwl omitted: overlaps .flash
    assert len(STITCH_REGIONS) == 24


def test_csm_pwl_is_read_last_so_it_cannot_trip_the_lock_early():
    assert DUMP_REGIONS[-1].name == "csm_pwl"


def test_literal_range_tokens_match_their_parsed_values():
    for r in DUMP_REGIONS:
        assert int(r.addr_hex, 16) == r.addr
        assert int(r.length_hex, 16) == r.length_words


def test_page_means_different_things_in_the_two_tables():
    # dslite address-space tag vs TI linker PAGE; m0_saram differs.
    dump_m0 = next(r for r in DUMP_REGIONS if r.name == "m0_saram")
    link_m0 = next(r for r in LINK_REGIONS if r.section == "m0_saram")
    assert dump_m0.page == 0
    assert link_m0.page == 1


def test_every_region_fits_inside_the_chip_image():
    for r in STITCH_REGIONS:
        assert r.chip_addr * 2 < CHIP_BYTES
