# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
# Binary Ninja - reverse engineering platform
#
# Options only. The install lives in the matching home-manager module
# (homeModules.binaryninja), which reads these through osConfig.
#
# Usage:
#   features.development.binaryninja = {
#     enable = true;
#     sha256 = "<base32 of your binaryninja_linux_dev_ultimate.zip>";
#     sidekick.enable = true;   # optional, see below
#     mcp.enable = true;        # optional, see below
#   };
{
  config,
  lib,
  ...
}:
let
  cfg = config.features.development.binaryninja;
in
{
  options.features.development.binaryninja = {
    enable = lib.mkEnableOption "Binary Ninja reverse engineering platform";

    sha256 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "03ivd2iv9pa5xqw703aa46fzscb5shsxwj15vqwp6f6sj5kcpvaq";
      description = ''
        base32 sha256 of your binaryninja_linux_dev_ultimate.zip.

        Consumer-supplied rather than pinned here: the licensed build differs
        per user, so a shared pin would force everyone onto one exact
        dev-ultimate download.

        Obtain it by dropping the zip into the seclab-pkgs requiredFiles/
        directory and running `stage-required-files`, which also puts the
        artifact where requireFile can find it.

        Nullable so that merely importing this module does not oblige every
        host to carry a Binary Ninja licence; it is only required when
        `enable` is set, which the assertion below enforces.
      '';
    };

    mcp = {
      # Binary Ninja 6.0 ships an MCP server inside the UI in every edition.
      # This only flips the setting that starts it with the application; the
      # server is reachable without it via Plugins > MCP > Start Server.
      #
      # It listens on http://127.0.0.1:24642/mcp with no authorization.
      enable = lib.mkEnableOption "the built-in MCP server starting with the Binary Ninja UI";
    };

    sidekick = {
      # Off even when Binary Ninja is on: Sidekick is a separately licensed
      # Vector 35 extension, and enabling it resolves packages from PyPI.
      enable = lib.mkEnableOption "the Sidekick plugin's Python dependencies";

      pipPackages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "pysqlite3>=0.5.0"
          "pyright[nodejs]>=1.1.405"
          "tenacity>=8.5.0,<9"
        ];
        description = ''
          Sidekick pip requirements that the package closure cannot supply,
          in pip requirement syntax.

          The default is Sidekick 26.1.521's declared set minus everything
          homeModules.binaryninja already puts on the plugin PYTHONPATH:
          nixpkgs carries no pysqlite3 and no pyright, and its tenacity is 9.x
          against Sidekick's <9 bound. An option rather than a constant so a
          newer Sidekick can be followed without changing this flake.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.sha256 != null;
          message = ''
            features.development.binaryninja.enable is on but sha256 is unset.
            Drop binaryninja_linux_dev_ultimate.zip into seclab-pkgs'
            requiredFiles/ and run `stage-required-files` to get the hash.
          '';
        }
      ];
    })
    {
      # Outside the mkIf above: the point is to catch a sub-option being
      # switched on while Binary Ninja itself is off
      assertions = [
        {
          assertion = cfg.sidekick.enable -> cfg.enable;
          message = ''
            features.development.binaryninja.sidekick.enable is on but
            features.development.binaryninja.enable is off. Sidekick's
            dependencies are only useful to a Binary Ninja install.
          '';
        }
        {
          assertion = cfg.mcp.enable -> cfg.enable;
          message = ''
            features.development.binaryninja.mcp.enable is on but
            features.development.binaryninja.enable is off. The MCP server
            runs inside Binary Ninja, so there is nothing to start.
          '';
        }
      ];
    }
  ];
}
