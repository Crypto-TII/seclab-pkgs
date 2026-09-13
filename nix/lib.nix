# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# flake-parts declares each flake output attribute unique, so `flake.lib` takes
# exactly one definition. Everything exported under it is assembled here.
_: {
  flake.lib = {
    # Each group individually, so a consumer can write
    #   buildInputs = seclab-pkgs.lib.toolsets.debugging { inherit pkgs; } ++ ...
    toolsets = {
      # keep-sorted start
      binary-analysis = import ../toolsets/binary-analysis.nix;
      crypto = import ../toolsets/crypto.nix;
      debugging = import ../toolsets/debugging.nix;
      dev-tools = import ../toolsets/dev-tools.nix;
      firmware = import ../toolsets/firmware.nix;
      forensics = import ../toolsets/forensics.nix;
      hardware = import ../toolsets/hardware.nix;
      python = import ../toolsets/python.nix;
      reversing = import ../toolsets/reversing.nix;
      # keep-sorted end
    };

    # Not toolsets.default: `toolsets` stays a flat group -> builder map, so
    # mapAttrs over it cannot trip on an entry that is not a group.
    mkToolsets = import ../toolsets;

    mkMcpConfig = import ./mcp-config.nix;
  };
}
