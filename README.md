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
  exclusions.nix          packages held out of CI checks / the devshell
  treefmt.nix             formatter configuration (`nix fmt`)
  update.nix              per-package update policy for `update-packages`
  update-packages.sh      the runner itself
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

3. Give it an update policy in [`nix/update.nix`](nix/update.nix). Evaluation
   fails until you do — see below.

To keep a package out of CI builds or out of `nix develop` (vendor blobs, or
anything too heavy to build on every PR), add it to
[`nix/exclusions.nix`](nix/exclusions.nix). It stays in `packages`, so
`nix build .#<name>` and `nix flake show` keep working.

## Keeping dependencies current

`nix flake update` moves `flake.lock`, and nothing else. Every version pinned
_inside_ `packages/` is invisible to it — a `fetchPypi` version+hash, a
`fetchFromGitHub` rev, a bare version string interpolated into a script. Those
go stale silently. The two commands are complements, not alternatives:

```sh
nix flake update      # flake inputs (nixpkgs, crane, ...)
update-packages       # version pins inside packages/
```

`update-packages` is on `$PATH` in `nix develop`, or run it as
`nix run .#update-packages`. It rewrites files in place and prints a summary;
review `git diff`, then `nix fmt && nix flake check`. Extra arguments are
forwarded to `nix-update` (`--build` and `--commit` are the useful ones).

Packages it cannot bump automatically — vendor downloads behind a portal, and
temporary overrides waiting on nixpkgs — are listed in the summary with their
current version rather than skipped silently.

Every package must appear in exactly one bucket of `policy` in
[`nix/update.nix`](nix/update.nix) (`auto`, `manual`, `pinned`, or `derived`).
Adding a package without classifying it fails evaluation — including in
`nix flake check` — which is what stops the next one from quietly rotting.

## Modules

Some things need more than a package attribute. Binary Ninja is installed by
overriding an upstream derivation's source and `installPhase`, and needs a
sha256 that differs per user, so it ships as a module pair rather than an
overlay entry:

| Output                     | Provides                                           |
| -------------------------- | -------------------------------------------------- |
| `nixosModules.binaryninja` | `features.development.binaryninja.{enable,sha256}` |
| `homeModules.binaryninja`  | the install itself, read from `osConfig`           |

```nix
# NixOS
imports = [ inputs.seclab-pkgs.nixosModules.binaryninja ];
features.development.binaryninja = {
  enable = true;
  sha256 = "<from stage-required-files>";
};

# home-manager
imports = [ inputs.seclab-pkgs.homeModules.binaryninja ];
```

> **`homeModules.binaryninja` also requires `overlays.default`.** It puts
> `pkgs.svd2py` on the Binary Ninja plugin PYTHONPATH, so the overlay must be
> applied to whatever `pkgs` home-manager uses. The module asserts this, so a
> missing overlay fails at evaluation with an explanation rather than at build
> time with `attribute 'svd2py' missing`.

The zip itself goes in [`requiredFiles/`](requiredFiles) — see its README.

## Consuming from another flake

```nix
{
  inputs.seclab-pkgs.url = "github:Crypto-TII/seclab-pkgs";

  outputs = { nixpkgs, seclab-pkgs, ... }: {
    # either via the overlay
    #   nixpkgs.overlays = [ seclab-pkgs.overlays.default ];
    # or directly
    #   seclab-pkgs.packages.x86_64-linux.<name>
    #
    # modules are a separate output kind -- overlays.default contributes
    # package attributes, nixosModules/homeModules contribute options.
  };
}
```
