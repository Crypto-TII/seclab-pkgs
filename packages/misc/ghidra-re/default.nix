# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# Ghidra with ReVa plus the firmware/analysis extensions from nixpkgs.
# withExtensions symlink-joins the extension outputs and exposes them through
# NIX_GHIDRAHOME as an additional application root.
{
  ghidra,
  reva-ghidra-extension,
}:

ghidra.withExtensions (
  p:
  (with p; [
    findcrypt
    ghidra-firmware-utils
    ghidra-golanganalyzerextension
    ghidraninja-ghidra-scripts
    kaiju
    lightkeeper
    ret-sync
    # ghidra-extensions.wasm is marked broken in this pin.
  ])
  ++ [ reva-ghidra-extension ]
)
