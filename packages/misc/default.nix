# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ callPackage }:
let
  binexportSource = callPackage ./binexport-source.nix { };
in
{
  # keep-sorted start
  bindiff = callPackage ./bindiff { inherit binexportSource; };
  freetoken = callPackage ./freetoken { };
  ghidra-binexport = callPackage ./ghidra-binexport { inherit binexportSource; };
  ghidra-re = callPackage ./ghidra-re { };
  proploader = callPackage ./proploader { };
  stage-required-files = callPackage ./stage-required-files { };
  stm32cubeprogrammer = callPackage ./stm32cubeprogrammer { };
  uniflash = callPackage ./uniflash { };
  # keep-sorted end
}
