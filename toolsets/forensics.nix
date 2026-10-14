# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ pkgs }:
with pkgs;
[
  # keep-sorted start
  ddrescue
  exiftool
  foremost
  # hivexget/hivexsh read Windows registry hives straight from an image,
  # without a Windows host or a mounted filesystem.
  hivex
  # ewfinfo/ewfexport/ewfmount for E01 (Expert Witness) images. ewfmount needs
  # the fuse-enabled build from overlays/libewf.nix.
  libewf
  # Needed to mount NTFS images where the kernel ntfs3 driver is unavailable.
  ntfs3g
  scalpel
  sleuthkit
  testdisk
  volatility3
  # keep-sorted end
]
