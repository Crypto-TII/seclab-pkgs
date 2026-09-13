# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{
  perSystem =
    { pkgs, ... }:
    let
      mcpConfig = import ./mcp-config.nix { inherit pkgs; };
    in
    {
      packages.mcp-config = mcpConfig;

      # Prints the path rather than linking it: where the config belongs is the
      # user's decision, and a shell hook writing .mcp.json into the working
      # tree is not one this repo makes for them.
      devshells.default.commands = [
        {
          name = "mcp-config";
          category = "maintenance";
          help = "print the path of the generated MCP client config";
          command = ''printf '%s\n' "${mcpConfig}"'';
        }
      ];
    };
}
