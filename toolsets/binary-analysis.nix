# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ pkgs }:
let
  seclab = import ./lib.nix { inherit pkgs; };
in
seclab.requireSeclabPkgs (
  with pkgs;
  [
    # keep-sorted start
    bloaty
    capstone
    checksec
    # Minimal, not full: the full build drags ghc, ocaml, mono and four JDKs.
    diffoscopeMinimal
    elfutils
    keystone
    # libtriton, not triton: the module it installs is named triton, which
    # would collide with python3Packages.triton.
    libtriton
    lief
    pahole
    pax-utils
    pev
    unicorn
    yara-x
    # keep-sorted end
  ]
  ++ lib.optionals stdenv.hostPlatform.isx86_64 [
    aflplusplus
    bindiff
    # meta.platforms is x86_64-linux; upstream treats aarch64 as a cross target.
    dynamorio
  ]
)
