# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  imports = [ inputs.git-hooks-nix.flakeModule ];
  perSystem =
    {
      config,
      pkgs,
      self',
      lib,
      ...
    }:
    {
      # Every package in this repo is also a check, plus the pre-commit hooks
      checks = {
        pre-commit-check = config.pre-commit.devShell;
      }
      // (
        let
          # Filter out function attributes like 'override' and 'overrideDerivation'
          isPackage =
            name: _value:
            !(lib.elem name [
              "override"
              "overrideDerivation"
            ]);
          packageAttrs = lib.filterAttrs isPackage self'.packages;
        in
        lib.mapAttrs' (n: lib.nameValuePair "package-${n}") packageAttrs
      );

      pre-commit = {
        settings = {
          hooks = {
            treefmt = {
              enable = true;
              package = config.treefmt.build.wrapper;
              stages = [ "pre-push" ];
            };
            reuse = {
              enable = true;
              package = pkgs.reuse;
              stages = [ "pre-push" ];
            };
            end-of-file-fixer = {
              enable = true;
              stages = [ "pre-push" ];
            };
          };
        };
      };
    };
}
