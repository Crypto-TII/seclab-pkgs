# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
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
