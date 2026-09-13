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
    biosutilities
    binwalk
    cabextract
    coreboot-utils
    cramfsswap
    dtc
    efitools
    fiano
    jefferson
    lz4
    mtdutils
    p7zip
    psptool
    sasquatch
    sbsigntool
    squashfsTools
    srecord
    ubi_reader
    uefi-firmware-parser
    uefitool
    # keep-sorted end
    # chipsec and unblob are missing on purpose: chipsec's test suite trips
    # python3.14's stricter logging %-formatting, and unblob's fs dependency
    # does not support 3.14 at all in this pin.
  ]
)
