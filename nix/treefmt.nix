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
          # Nix
          # nix standard formatter according to rfc 166 (https://github.com/NixOS/rfcs/pull/166)
          nixfmt.enable = true;
          nixfmt.package = pkgs.nixfmt;

          deadnix.enable = true; # removes dead nix code https://github.com/astro/deadnix
          statix.enable = true; # prevents use of nix anti-patterns https://github.com/nerdypepper/statix

          # Python
          # Ruff, a Python formatter and linter written in Rust.
          ruff.check = true;
          ruff.format = true;

          # Bash
          shellcheck.enable = true; # lints shell scripts https://github.com/koalaman/shellcheck

          yamlfmt.enable = true; # YAML formatter
          prettier.enable = true; # JavaScript / Markdown / JSON formatter

          # C/C++
          clang-format.enable = true;

          # Rust
          rustfmt.enable = true;

          # Go
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
