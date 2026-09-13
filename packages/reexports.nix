# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# Attributes that exist only because overlays.default was applied, surfaced in
# `packages` so a plain-flake consumer can reach them. Plain data, with no
# arguments, so nix/update.nix can read the names without a `pkgs`.
{
  # keep-sorted start
  # The overlay's whole reason to exist, and nothing else builds it.
  angr = [
    "python313Packages"
    "angr"
  ];
  # From tms320c28x-re's overlay.
  c28x = [
    "python3Packages"
    "c28x"
  ];
  # From overlays/pwndbg.nix. Only these two of the two dozen attributes
  # upstream publishes.
  pwndbg = [ "pwndbg" ];
  pwndbg-lldb = [ "pwndbg-lldb" ];
  # keep-sorted end
}
