<!--
SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
SPDX-License-Identifier: Apache-2.0
-->

# seclab-pkgs

A collection of Nix packages maintained by the TII Secure Systems Research Lab.

## Layout

```
flake.nix                 flake entry point (flake-parts)
default.nix               flake-compat shim for non-flake consumers
nix/
  flake-module.nix        imports the modules below
  checks.nix              pre-commit hooks + every package exposed as a check
  devshell.nix            `nix develop` / direnv environment
  treefmt.nix             formatter configuration (`nix fmt`)
packages/
  flake-module.nix        assembles all packages + `overlays.default`
  cpp/                    C/C++ packages
  go/                     Go packages
  python/                 Python packages
  rust/                   Rust packages (built with crane)
```

## Usage

Enter the development shell:

```sh
nix develop        # or: direnv allow
```

Common commands:

```sh
nix fmt            # format the tree with treefmt
nix flake check    # run all checks (builds every package)
nix flake show     # list outputs
nix build .#<pkg>  # build a single package
```

## Adding a package

1. Create `packages/<language>/<name>/` containing the package definition
   (`default.nix`, or `package.nix` for Python packages).
2. Register it in `packages/<language>/default.nix`.

It is then automatically available as `packages.<system>.<name>`, as a check,
and through `overlays.default`.

## Consuming from another flake

```nix
{
  inputs.seclab-pkgs.url = "github:Crypto-TII/seclab-pkgs";

  outputs = { nixpkgs, seclab-pkgs, ... }: {
    # either via the overlay
    #   nixpkgs.overlays = [ seclab-pkgs.overlays.default ];
    # or directly
    #   seclab-pkgs.packages.x86_64-linux.<name>
  };
}
```
