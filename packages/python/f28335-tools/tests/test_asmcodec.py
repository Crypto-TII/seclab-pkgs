# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
"""The .asm encoder must stay bit-exact.

It replaced an `od -An -v -tx2 -w2 | awk` pipeline, and its output feeds the
linker whose COFF is then checked byte-for-byte against the raw dump. A change
here surfaces as a byte-fidelity failure, so pin the shape directly.
"""

import struct

from f28335_tools.asmcodec import MIN_RUN, encode_words


def _words(values):
    return b"".join(struct.pack("<H", v) for v in values)


def test_short_run_emits_one_word_per_value_with_address_comments():
    out = encode_words(_words([0x1234, 0x5678]), origin=0x300000)
    assert out == "\t.word\t0x1234\t; 0x300000\n\t.word\t0x5678\t; 0x300001\n"


def test_run_at_threshold_is_compressed():
    out = encode_words(_words([0xFFFF] * MIN_RUN), origin=0)
    assert out == f"\t.loop\t{MIN_RUN}\n\t.word\t0xFFFF\n\t.endloop\n"


def test_run_one_below_threshold_is_not_compressed():
    out = encode_words(_words([0xFFFF] * (MIN_RUN - 1)), origin=0)
    assert ".loop" not in out
    assert out.count(".word") == MIN_RUN - 1


def test_addresses_continue_across_a_compressed_run():
    # origin + 8 words of run, so the trailing single word is at origin+8.
    out = encode_words(_words([0xAAAA] * MIN_RUN + [0x0001]), origin=0x1000)
    assert out.endswith("\t.word\t0x0001\t; 0x001008\n")


def test_hex_is_upper_case_like_the_original_awk():
    out = encode_words(_words([0xABCD]), origin=0)
    assert "0xABCD" in out


def test_little_endian_word_order():
    # bytes CD AB -> word 0xABCD
    out = encode_words(b"\xcd\xab", origin=0)
    assert "0xABCD" in out
