# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# Only targets whose gcc and glibc cache.nixos.org serves for x86_64-linux;
# cross-extra.nix holds the ones that build locally.
{ pkgs }:
let
  seclab = import ./lib.nix { inherit pkgs; };
in
seclab.mkCross "cross" (
  with pkgs.pkgsCross;
  {
    # keep-sorted start
    aarch64 = aarch64-multiplatform;
    arm = armv7l-hf-multiplatform;
    i386 = gnu32;
    mips64el = mips64el-linux-gnuabi64;
    mipsel = mipsel-linux-gnu;
    # ELFv1, not nixpkgs' default ppc64: big-endian binaries in the wild are
    # ELFv1 and ask for ld64.so.1, which an ELFv2 glibc does not provide.
    ppc64 = ppc64-elfv1;
    ppc64le = powernv;
    inherit riscv64;
    # keep-sorted end
  }
)
