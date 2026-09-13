# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{
  description = "A collection of packages maintained by the TII Secure Lab";
  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://ghaf-dev.cachix.org?priority=50"
      "https://nix-community.cachix.org"
      "https://pwndbg.cachix.org"
    ];
    extra-substituters = [
      "https://cache.nixos.org"
      "https://ghaf-dev.cachix.org?priority=50"
      "https://nix-community.cachix.org"
      "https://pwndbg.cachix.org"
    ];
    extra-trusted-public-keys = [
      "ghaf-dev.cachix.org-1:S3M8x3no8LFQPBfHw1jl6nmP8A7cVWKntoMKN3IsEQY="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "pwndbg.cachix.org-1:HhtIpP7j73SnuzLgobqqa8LVTng5Qi36sQtNt79cD3k="
    ];

    allow-import-from-derivation = false;
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    crane = {
      url = "github:ipetkov/crane";
    };

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # For preserving compatibility with non-Flake users
    flake-compat = {
      url = "github:nix-community/flake-compat";
      flake = false;
    };

    # The modules/ tree overrides its source and installPhase. x86_64-linux only.
    nix-binary-ninja = {
      url = "github:jchv/nix-binary-ninja";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    flake-root.url = "github:srid/flake-root";

    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };

    # Removed from nixpkgs in 2025-02; upstream ships its own flake. No
    # `follows`: its flake imports a nixpkgs of its own and its uv.lock was
    # resolved against that interpreter, so redirecting it would rebuild every
    # sdist in the lock against a Python upstream never resolved for, and void
    # pwndbg.cachix.org.
    pwndbg = {
      url = "github:pwndbg/pwndbg";
    };

    # Its overlay is composed into ours so consumers get python3Packages.c28x.
    tms320c28x-re = {
      url = "github:brianmcgillion/tms320c28x-re";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./modules/flake-module.nix
        ./nix/flake-module.nix
        ./packages/flake-module.nix
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
}
