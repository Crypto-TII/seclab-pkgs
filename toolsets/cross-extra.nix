# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# Not in cache.nixos.org: enabling this builds a cross gcc and glibc per target.
{ pkgs }:
let
  seclab = import ./lib.nix { inherit pkgs; };
in
seclab.mkCross "cross-extra" (
  with pkgs.pkgsCross;
  {
    # keep-sorted start
    mips = mips-linux-gnu;
    mips64 = mips64-linux-gnuabi64;
    ppc = ppc32;
    # keep-sorted end
  }
)
