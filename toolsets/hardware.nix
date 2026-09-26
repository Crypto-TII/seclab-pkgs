# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ pkgs }:
let
  seclab = import ./lib.nix { inherit pkgs; };

  # write_chip_bad_status_test fails on aarch64 in this pin; Hydra has no build.
  flashrom =
    if pkgs.stdenv.hostPlatform.isAarch64 then
      pkgs.flashrom.overrideAttrs { doCheck = false; }
    else
      pkgs.flashrom;
in
seclab.requireSeclabPkgs (
  with pkgs;
  [
    # keep-sorted start
    avrdude
    can-utils
    dfu-util
    esptool
    flashrom
    i2c-tools
    libgpiod
    minicom
    openocd
    pciutils
    picocom
    probe-rs-tools
    proploader
    pulseview
    pyocd
    sigrok-cli
    spi-tools
    stlink
    svd2py
    tio
    urjtag
    usbutils
    # keep-sorted end
    # stm32cubeprogrammer is missing on purpose: requireFile, so a consumer who
    # has not staged the ST zip cannot even evaluate this list.
  ]
  ++ lib.optionals stdenv.hostPlatform.isx86_64 [
    saleae-logic-2
    # uniflash and f28335-tools, which wraps it, are missing for the same
    # reason: the TI installer is a requireFile.
  ]
)
