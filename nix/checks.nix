# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
let
  exclusions = import ./exclusions.nix;
in
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
      checks = {
        pre-commit-check = config.pre-commit.devShell;
      }
      // (
        let
          isPackage =
            name: value:
            !(lib.elem name (
              [
                "override"
                "overrideDerivation"
              ]
              ++ exclusions.checks
            ))
            # meta.platforms rather than the exclusion list: an x86_64-only
            # package throws at drvPath on aarch64, which would fail the whole
            # aarch64 check set rather than skip one entry.
            && lib.meta.availableOn pkgs.stdenv.hostPlatform value;
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
