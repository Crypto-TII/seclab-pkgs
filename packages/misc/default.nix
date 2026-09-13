# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ callPackage }:
{
  # keep-sorted start
  freetoken = callPackage ./freetoken { };
  ghidra-re = callPackage ./ghidra-re { };
  proploader = callPackage ./proploader { };
  stage-required-files = callPackage ./stage-required-files { };
  stm32cubeprogrammer = callPackage ./stm32cubeprogrammer { };
  uniflash = callPackage ./uniflash { };
  # keep-sorted end
}
