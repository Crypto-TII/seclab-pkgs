# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  imports = [
    inputs.flake-root.flakeModule
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    { config, pkgs, ... }:
    {
      treefmt = {
        inherit (config.flake-root) projectRootFile;

        programs = {
          # RFC 166: https://github.com/NixOS/rfcs/pull/166
          nixfmt.enable = true;
          nixfmt.package = pkgs.nixfmt;

          deadnix.enable = true;
          statix.enable = true;

          ruff.check = true;
          ruff.format = true;

          shellcheck.enable = true;

          yamlfmt.enable = true;
          prettier.enable = true;

          clang-format.enable = true;
          rustfmt.enable = true;
          gofmt.enable = true;
        };

        settings.global.excludes = [
          "*.lock"
          "*.png"
          "*.svg"
          "*.license"
          "*.txt"
          # Key material and certificates
          "*.key"
          "*.pem"
          "*.crt"
          "*.cer"
          "*.csr"
          "*.der"
          "*.p12"
          "*.pfx"
          "*.jks"
          "*.keystore"
        ];
      };

      formatter = config.treefmt.build.wrapper;
    };
}
