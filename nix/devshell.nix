# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ inputs, lib, ... }:
{
  imports = [
    inputs.devshell.flakeModule
  ];
  perSystem =
    {
      self',
      pkgs,
      config,
      ...
    }:
    {
      devshells.default = {
        devshell = {
          name = "seclab-pkgs devshell";
          meta.description = "seclab-pkgs development environment";
          packages = [
            pkgs.bashInteractive
            pkgs.nixVersions.latest
            pkgs.nix-eval-jobs
            pkgs.nix-fast-build
            pkgs.nix-output-monitor
            pkgs.nix-tree
            pkgs.reuse

            pkgs.stdenv.cc
            pkgs.pkg-config

            config.treefmt.build.wrapper
          ]
          ++ config.pre-commit.settings.enabledPackages
          ++ lib.attrValues config.treefmt.build.programs; # make all the treefmt packages available

          startup.hook.text = config.pre-commit.installationScript;

          # Pull in the build inputs of every package defined in this repo.
          packagesFrom =
            let
              excluded = [
                # Function attributes, not packages.
                "override"
                "overrideDerivation"
              ]
              # Heavy or conflicting closures.
              ++ (import ./exclusions.nix).devshell;
              isPackage = name: _value: !(lib.elem name excluded);
            in
            lib.attrValues (lib.filterAttrs isPackage self'.packages);
        };

        env = [
          {
            name = "PKG_CONFIG_PATH";
            prefix = "$DEVSHELL_DIR/lib/pkgconfig";
          }
        ];
      };
    };
}
