# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# An MCP client config as a value. Nothing here writes to a working tree: the
# consumer links the result where they want it.
{
  pkgs,
  # A store path, so this drags ghidra-re's closure into whatever builds the
  # config. null drops the server.
  ghidra ? pkgs.ghidra-re,
  # A bare PATH name, not a store path: homeModules.binaryninja builds the
  # wrapper from a licensed zip with a per-user sha256, and only when that zip
  # contains it, so no flake-level attribute for it can exist. A derivation
  # works too, for a caller that has one.
  binaryNinja ? "binaryninja_mcp",
  extraServers ? { },
}:
let
  inherit (pkgs) lib;

  # mcp-reva is ReVa's headless half; the Ghidra-side plugin is
  # ghidra-extensions.reva, which ghidra-re carries. One release, two halves --
  # they must not drift.
  reva = lib.optionalAttrs (ghidra != null) {
    mcp-reva = {
      command = lib.getExe pkgs.mcp-reva;
      args = [ ];
      env.GHIDRA_INSTALL_DIR = "${ghidra}/lib/ghidra";
    };
  };

  binja = lib.optionalAttrs (binaryNinja != null) {
    binaryninja = {
      command =
        if lib.isString binaryNinja then binaryNinja else lib.getExe' binaryNinja "binaryninja_mcp";
      args = [ ];
    };
  };
in
# Not ".mcp.json": nix rejects a store path name that starts with a dot.
(pkgs.formats.json { }).generate "mcp.json" {
  mcpServers = reva // binja // extraServers;
}
