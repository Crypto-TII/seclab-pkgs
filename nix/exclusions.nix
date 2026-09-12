# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# Packages held out of CI checks and/or the devshell. They stay in
# perSystem.packages, so `nix build .#<name>` and nix/update.nix still see them.
{
  # Dropped from the `package-<name>` checks in nix/checks.nix.
  checks = [
    # keep-sorted start
    # Unfree CUDA 13 closure, and the derivation is only the FHS sandbox --
    # everything that can break happens at runtime inside it.
    "freetoken"
    # Ghidra plus seven extensions.
    "ghidra-re"
    # requireFile behind an ST login.
    "stm32cubeprogrammer"
    # Large vendor installer from TI.
    "uniflash"
    # keep-sorted end
  ];

  # Dropped from packagesFrom in nix/devshell.nix.
  devshell = [
    # keep-sorted start
    "freetoken"
    "ghidra-re"
    # python313: a second interpreter collides with the 3.14 packages on
    # bin/idle3.
    "mcp-reva"
    "stm32cubeprogrammer"
    "uniflash"
    # keep-sorted end
  ];
}
