# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# Held out of CI checks and/or the devshell. These stay in perSystem.packages,
# so `nix build .#<name>` and nix/update.nix still see them.
{
  checks = [
    # keep-sorted start
    # Half-hour from-source build behind a submodule fetch.
    "dynamorio"
    # Unfree CUDA 13 closure, and the derivation is only the FHS sandbox.
    "freetoken"
    # Ghidra plus seven extensions.
    "ghidra-re"
    # ~19k lines of generated semantics in one TU at -O3, plus LLVM.
    "libtriton"
    # requireFile behind an ST login.
    "stm32cubeprogrammer"
    # Large vendor installer from TI.
    "uniflash"
    # keep-sorted end
  ];

  devshell = [
    # keep-sorted start
    "freetoken"
    "ghidra-re"
    "stm32cubeprogrammer"
    "uniflash"
    # keep-sorted end
  ];
}
