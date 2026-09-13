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
    f28335-tools
    saleae-logic-2
    uniflash
  ]
)
