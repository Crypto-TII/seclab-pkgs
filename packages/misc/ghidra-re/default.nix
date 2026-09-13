# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{
  ghidra,
  ghidra-binexport,
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
    reva
    # ghidra-extensions.wasm is marked broken in this pin.
  ])
  # Not in nixpkgs, and the one thing here that writes the .BinExport files
  # bindiff reads.
  ++ [ ghidra-binexport ]
)
