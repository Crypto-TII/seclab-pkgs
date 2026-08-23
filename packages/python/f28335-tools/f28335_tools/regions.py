# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
"""F28335 memory region tables.

Transcribed mechanically from the arrays in the dump_f28335.sh /
reconstruct_f28335.sh / stitch_f28335.sh scripts this package replaces.

Deliberately three separate tables: `page` means different things in
DUMP_REGIONS (the C28x address-space tag for dslite --range: 0 = PROGRAM,
1 = DATA) and in LINK_REGIONS (the TI linker PAGE). m0_saram is page 0 for
dslite but page 1 for the linker.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class DumpRegion:
    """One dslite capture: --range=<addr>@<page>,<length>."""

    name: str
    addr: int
    length_words: int
    page: int
    note: str
    # Literal tokens from the original table. The --range argument is built
    # from these so the command line stays byte-identical to the shell: the
    # csm_pwl address is written 0x33FFF8 in upper case, and there is no
    # reason to gamble on dslite's hex parser being case-insensitive.
    addr_hex: str
    length_hex: str


@dataclass(frozen=True)
class LinkRegion:
    """One reconstructed section and its linker MEMORY entry."""

    bin_name: str
    section: str
    region: str
    page: int
    origin: int
    length_words: int


@dataclass(frozen=True)
class StitchRegion:
    """One region placed into the flat chip image at chip_addr * 2."""

    bin_name: str
    chip_addr: int


# csm_pwl is read LAST on purpose: reading it earlier can trip the CSM lock
# for the rest of the run. Preserve this order.
DUMP_REGIONS: tuple[DumpRegion, ...] = (
    DumpRegion(
        "m0_saram", 0x000000, 0x0400, 0, "M0 SARAM (1 KW = 2 KB)", "0x000000", "0x0400"
    ),
    DumpRegion(
        "m1_saram", 0x000400, 0x0400, 0, "M1 SARAM (1 KW = 2 KB)", "0x000400", "0x0400"
    ),
    DumpRegion(
        "pf0",
        0x000800,
        0x1800,
        1,
        "PF0 + adj regs: PIE/Flash/CSM/CPU-Timer/ADC/XINTF (DATA, 6 KW)",
        "0x000800",
        "0x1800",
    ),
    DumpRegion(
        "pf3", 0x005000, 0x1000, 1, "PF3: McBSP regs (DATA, 4 KW)", "0x005000", "0x1000"
    ),
    DumpRegion(
        "pf1",
        0x006000,
        0x1000,
        1,
        "PF1: eCAN/ePWM/eCAP/eQEP/GPIO regs (DATA, 4 KW)",
        "0x006000",
        "0x1000",
    ),
    DumpRegion(
        "pf2",
        0x007000,
        0x1000,
        1,
        "PF2: SysCtrl/SCI/SPI/I2C/ADC regs (DATA, 4 KW)",
        "0x007000",
        "0x1000",
    ),
    DumpRegion(
        "saram_l0", 0x008000, 0x1000, 0, "L0 SARAM (4 KW)", "0x008000", "0x1000"
    ),
    DumpRegion(
        "saram_l1", 0x009000, 0x1000, 0, "L1 SARAM (4 KW)", "0x009000", "0x1000"
    ),
    DumpRegion(
        "saram_l2", 0x00A000, 0x1000, 0, "L2 SARAM (4 KW)", "0x00a000", "0x1000"
    ),
    DumpRegion(
        "saram_l3", 0x00B000, 0x1000, 0, "L3 SARAM (4 KW)", "0x00b000", "0x1000"
    ),
    DumpRegion(
        "saram_l4", 0x00C000, 0x1000, 0, "L4 SARAM (4 KW)", "0x00c000", "0x1000"
    ),
    DumpRegion(
        "saram_l5", 0x00D000, 0x1000, 0, "L5 SARAM (4 KW)", "0x00d000", "0x1000"
    ),
    DumpRegion(
        "saram_l6", 0x00E000, 0x1000, 0, "L6 SARAM (4 KW)", "0x00e000", "0x1000"
    ),
    DumpRegion(
        "saram_l7", 0x00F000, 0x1000, 0, "L7 SARAM (4 KW)", "0x00f000", "0x1000"
    ),
    DumpRegion(
        "flash",
        0x300000,
        0x40000,
        0,
        "Flash sectors A..H (256 KW) - blocked if CSM locked",
        "0x300000",
        "0x40000",
    ),
    DumpRegion(
        "adc_cal",
        0x380080,
        0x0009,
        0,
        "TI-OTP ADC_cal data (9 W; only mapped TI-OTP window)",
        "0x380080",
        "0x0009",
    ),
    DumpRegion(
        "partid", 0x380090, 0x0001, 0, "TI-OTP PARTID (1 W)", "0x380090", "0x0001"
    ),
    DumpRegion(
        "user_otp",
        0x380400,
        0x0400,
        0,
        "User OTP (1 KW) - blocked if CSM locked",
        "0x380400",
        "0x0400",
    ),
    DumpRegion(
        "saram_l0_pgm",
        0x3F8000,
        0x1000,
        0,
        "L0 SARAM program-page mirror (4 KW)",
        "0x3f8000",
        "0x1000",
    ),
    DumpRegion(
        "saram_l1_pgm",
        0x3F9000,
        0x1000,
        0,
        "L1 SARAM program-page mirror (4 KW)",
        "0x3f9000",
        "0x1000",
    ),
    DumpRegion(
        "saram_l2_pgm",
        0x3FA000,
        0x1000,
        0,
        "L2 SARAM program-page mirror (4 KW)",
        "0x3fa000",
        "0x1000",
    ),
    DumpRegion(
        "saram_l3_pgm",
        0x3FB000,
        0x1000,
        0,
        "L3 SARAM program-page mirror (4 KW)",
        "0x3fb000",
        "0x1000",
    ),
    DumpRegion("bootrom", 0x3FE000, 0x2000, 0, "Boot ROM (8 KW)", "0x3fe000", "0x2000"),
    DumpRegion(
        "csm_pwl",
        0x33FFF8,
        0x0008,
        0,
        "CSM password locations (last)",
        "0x33FFF8",
        "0x0008",
    ),
)


# csm_pwl is omitted: it overlaps the top of .flash (0x33FFF8..0x33FFFF)
# and would be a linker overlap error.
LINK_REGIONS: tuple[LinkRegion, ...] = (
    LinkRegion("m0_saram.bin", "m0_saram", "M0RAM", 1, 0x000000, 0x0400),
    LinkRegion("m1_saram.bin", "m1_saram", "M1RAM", 1, 0x000400, 0x0400),
    LinkRegion("pf0.bin", "pf0", "PF0", 1, 0x000800, 0x1800),
    LinkRegion("pf3.bin", "pf3", "PF3", 1, 0x005000, 0x1000),
    LinkRegion("pf1.bin", "pf1", "PF1", 1, 0x006000, 0x1000),
    LinkRegion("pf2.bin", "pf2", "PF2", 1, 0x007000, 0x1000),
    LinkRegion("saram_l0.bin", "saram_l0", "L0SARAM", 1, 0x008000, 0x1000),
    LinkRegion("saram_l1.bin", "saram_l1", "L1SARAM", 1, 0x009000, 0x1000),
    LinkRegion("saram_l2.bin", "saram_l2", "L2SARAM", 1, 0x00A000, 0x1000),
    LinkRegion("saram_l3.bin", "saram_l3", "L3SARAM", 1, 0x00B000, 0x1000),
    LinkRegion("saram_l4.bin", "saram_l4", "L4SARAM", 1, 0x00C000, 0x1000),
    LinkRegion("saram_l5.bin", "saram_l5", "L5SARAM", 1, 0x00D000, 0x1000),
    LinkRegion("saram_l6.bin", "saram_l6", "L6SARAM", 1, 0x00E000, 0x1000),
    LinkRegion("saram_l7.bin", "saram_l7", "L7SARAM", 1, 0x00F000, 0x1000),
    LinkRegion("flash.bin", "flash", "FLASH", 0, 0x300000, 0x40000),
    LinkRegion("adc_cal.bin", "adc_cal", "ADC_CAL", 0, 0x380080, 0x0009),
    LinkRegion("partid.bin", "partid", "PARTID", 0, 0x380090, 0x0001),
    LinkRegion("user_otp.bin", "user_otp", "USER_OTP", 0, 0x380400, 0x0400),
    LinkRegion("saram_l0_pgm.bin", "saram_l0_pgm", "L0SARAM_PGM", 0, 0x3F8000, 0x1000),
    LinkRegion("saram_l1_pgm.bin", "saram_l1_pgm", "L1SARAM_PGM", 0, 0x3F9000, 0x1000),
    LinkRegion("saram_l2_pgm.bin", "saram_l2_pgm", "L2SARAM_PGM", 0, 0x3FA000, 0x1000),
    LinkRegion("saram_l3_pgm.bin", "saram_l3_pgm", "L3SARAM_PGM", 0, 0x3FB000, 0x1000),
    LinkRegion("bootrom.bin", "bootrom", "BOOTROM", 0, 0x3FE000, 0x2000),
)


# csm_pwl IS included here: it writes the same 16 bytes flash.bin already
# carries at chip 0x33FFF8, so the overlap is harmless.
STITCH_REGIONS: tuple[StitchRegion, ...] = (
    StitchRegion("m0_saram.bin", 0x000000),
    StitchRegion("m1_saram.bin", 0x000400),
    StitchRegion("pf0.bin", 0x000800),
    StitchRegion("pf3.bin", 0x005000),
    StitchRegion("pf1.bin", 0x006000),
    StitchRegion("pf2.bin", 0x007000),
    StitchRegion("saram_l0.bin", 0x008000),
    StitchRegion("saram_l1.bin", 0x009000),
    StitchRegion("saram_l2.bin", 0x00A000),
    StitchRegion("saram_l3.bin", 0x00B000),
    StitchRegion("saram_l4.bin", 0x00C000),
    StitchRegion("saram_l5.bin", 0x00D000),
    StitchRegion("saram_l6.bin", 0x00E000),
    StitchRegion("saram_l7.bin", 0x00F000),
    StitchRegion("flash.bin", 0x300000),
    StitchRegion("csm_pwl.bin", 0x33FFF8),
    StitchRegion("adc_cal.bin", 0x380080),
    StitchRegion("partid.bin", 0x380090),
    StitchRegion("user_otp.bin", 0x380400),
    StitchRegion("saram_l0_pgm.bin", 0x3F8000),
    StitchRegion("saram_l1_pgm.bin", 0x3F9000),
    StitchRegion("saram_l2_pgm.bin", 0x3FA000),
    StitchRegion("saram_l3_pgm.bin", 0x3FB000),
    StitchRegion("bootrom.bin", 0x3FE000),
)


# 4 M words = 8 MiB. Byte offset of a chip word address is addr * 2
# (Binary Ninja C28x convention: BN_byte = 2 * chip_word).
CHIP_BYTES = 0x800000
ERASED_BYTE = 0xFF
