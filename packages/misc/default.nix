# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# Packaged applications that are not built from source in a single language:
# vendor installers, prebuilt binaries, and shell front-ends over them. Add
# entries as:
#   { callPackage, ... }:
#   { my-tool = callPackage ./my-tool { }; }
#
# Note that packages/python/f28335-tools depends on uniflash from this set,
# which is why the overlay in ../flake-module.nix resolves through `final`
# rather than `prev`.
{ callPackage }:
{
  # keep-sorted start
  proploader = callPackage ./proploader { };
  stage-required-files = callPackage ./stage-required-files { };
  stm32cubeprogrammer = callPackage ./stm32cubeprogrammer { };
  uniflash = callPackage ./uniflash { };
  # keep-sorted end
}
