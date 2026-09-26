# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# The group names and whether each is on by default, without a `pkgs` in hand:
# the re-environment module declares one option per group and cannot
# instantiate nixpkgs to ask.
{
  # keep-sorted start
  binary-analysis = true;
  crypto = true;
  # Off: a cross gcc and glibc per target is a large closure few users need,
  # and cross-extra's targets are not in cache.nixos.org at all.
  cross = false;
  cross-extra = false;
  debugging = true;
  dev-tools = true;
  firmware = true;
  forensics = true;
  hardware = true;
  python = true;
  reversing = true;
  static-analysis = true;
  # keep-sorted end
}
