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
    binaryninja-free
    cutter
    detect-it-easy
    ghidra-re
    jadx
    krakatau2
    radare2
    rizin
    # keep-sorted end
  ]
  ++ lib.optionals stdenv.hostPlatform.isx86_64 [
    # x86_64-only in nixpkgs; throws at drvPath elsewhere.
    apktool
    # retdec is missing on purpose: 5.0 vendors LLVM and keystone trees whose
    # CMakeLists ask for compatibility with CMake < 3.5, which CMake 4 refuses,
    # so it does not build in this pin.
  ]
)
