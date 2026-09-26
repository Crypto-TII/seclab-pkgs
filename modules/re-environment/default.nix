# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# `seclabInputs`, not `inputs`: flake-parts passes the *consumer's* inputs as a
# module argument, and an outer argument by that name would shadow it.
{ seclabInputs }:
{ lib, config, ... }:
let
  cfg = config.seclab.re;

  groups = import ../../toolsets/groups.nix;
in
{
  options.seclab.re = {
    nixpkgs = lib.mkOption {
      type = lib.types.raw;
      default = seclabInputs.nixpkgs;
      defaultText = lib.literalExpression "seclab-pkgs' own nixpkgs input";
      description = "Nixpkgs source the RE shell is built from.";
    };

    extraOverlays = lib.mkOption {
      type = lib.types.listOf lib.types.raw;
      default = [ ];
      description = "Overlays stacked on top of seclab-pkgs' own.";
    };

    allowUnfree = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        ghidra-re and binwalk both reach dumpifs, which is unfree, so the shell
        does not evaluate without this.
      '';
    };

    shellName = lib.mkOption {
      type = lib.types.str;
      default = "re";
      description = ''
        Attribute under `devShells`. Not `default`: devShells does not merge two
        definitions of one name, so claiming it would collide with a consumer's
        own default shell.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages for the shell, on top of the toolsets.";
    };

    toolsets = lib.mapAttrs (
      group: enabledByDefault:
      lib.mkOption {
        type = lib.types.bool;
        default = enabledByDefault;
        description = "Include the ${group} toolset.";
      }
    ) groups;
  };

  config.perSystem =
    { system, ... }:
    let
      # Deliberately not _module.args.pkgs: a consumer's own definition of that
      # would win, handing them a shell built without overlays.default.
      seclabPkgs = import cfg.nixpkgs {
        inherit system;
        config.allowUnfree = cfg.allowUnfree;
        overlays = [ seclabInputs.self.overlays.default ] ++ cfg.extraOverlays;
      };

      toolsets = import ../../toolsets/default.nix {
        pkgs = seclabPkgs;
        enabled = cfg.toolsets;
      };
    in
    {
      _module.args.seclabPkgs = seclabPkgs;
      _module.args.seclabToolsets = toolsets;

      devShells.${cfg.shellName} = import ./shell.nix {
        pkgs = seclabPkgs;
        inherit toolsets;
        inherit (cfg) extraPackages;
      };
    };
}
