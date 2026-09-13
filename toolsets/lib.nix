# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ pkgs }:
{
  # Both conditions fail late and cryptically otherwise: a missing attribute at
  # access time, and an unfree throw from a transitive dependency.
  requireSeclabPkgs =
    value:
    assert pkgs.lib.assertMsg (pkgs ? ghidra-re) ''
      This toolset needs seclab-pkgs' own packages, which reach `pkgs` through
      the overlay:

        pkgs = import nixpkgs {
          inherit system;
          overlays = [ seclab-pkgs.overlays.default ];
        };

      Without it you get `attribute 'ghidra-re' missing`.
    '';
    assert pkgs.lib.assertMsg (pkgs.config.allowUnfree or false) ''
      This toolset needs `config.allowUnfree = true`. ghidra-re and binwalk both
      reach dumpifs through ghidraninja-ghidra-scripts, so they fail with
      `Refusing to evaluate package 'dumpifs-...'` otherwise.
    '';
    value;
}
