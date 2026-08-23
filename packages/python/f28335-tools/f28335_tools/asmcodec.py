# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
"""Encode a raw little-endian word stream as TI C2000 assembly.

Replaces the `od -An -v -tx2 -w2 | awk` pipeline that reconstruct_f28335.sh
used. Output must stay byte-identical to that pipeline: the reconstructed COFF
is checked against the raw dump for byte fidelity, and the .dis is only
trustworthy if it round-trips.
"""

from __future__ import annotations

import struct
from pathlib import Path

# Runs shorter than this are cheaper to spell out one .word at a time, and
# keeping the address comments makes the .asm readable.
MIN_RUN = 8

HEADER = """\
;==============================================================
; {section}.asm  --  f28335-dump reconstruct stage
;
; Source region : {source}
; Origin        : {origin}  (word address)
; Length        : {size_words} words ({size_bytes} bytes)
; Linker page   : {page}
;
; Encoding      : raw little-endian word stream
; Compression   : runs of >= 8 identical words emit a
;                 .loop / .word VAL / .endloop block; everything else
;                 emits one .word per 16-bit value with the absolute
;                 word address as a trailing comment.
;==============================================================
\t.sect\t".{section}"
"""


def _flush(word: str, run: int, start: int, out: list[str]) -> None:
    if run >= MIN_RUN:
        out.append(f"\t.loop\t{run}\n")
        out.append(f"\t.word\t0x{word}\n")
        out.append("\t.endloop\n")
    else:
        for i in range(run):
            out.append(f"\t.word\t0x{word}\t; 0x{start + i:06X}\n")


def encode_words(data: bytes, origin: int) -> str:
    """Run-length encode a word stream, mirroring the original awk exactly."""
    out: list[str] = []
    addr = origin
    prev: str | None = None
    run = 0
    # od -tx2 -w2 printed each little-endian word as 4 lowercase hex digits;
    # awk upper-cased them.
    for (value,) in struct.iter_unpack("<H", data):
        word = f"{value:04x}".upper()
        if run == 0:
            prev, run = word, 1
        elif word == prev:
            run += 1
        else:
            _flush(prev, run, addr - run, out)
            prev, run = word, 1
        addr += 1
    if run > 0:
        _flush(prev, run, addr - run, out)
    return "".join(out)


def encode_asm(
    bin_path: Path, out_path: Path, section: str, origin: int, page: int
) -> None:
    """Write ``<section>.asm`` for one region .bin."""
    data = bin_path.read_bytes()
    size_bytes = len(data)
    # Integer division mirrors the shell's $((size_bytes / 2)); a trailing odd
    # byte would be dropped by struct.iter_unpack too.
    size_words = size_bytes // 2
    header = HEADER.format(
        section=section,
        source=bin_path.name,
        origin=f"0x{origin:06x}",
        size_words=size_words,
        size_bytes=size_bytes,
        page=page,
    )
    out_path.write_text(header + encode_words(data, origin))
