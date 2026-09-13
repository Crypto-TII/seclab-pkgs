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
  lib.nix                 everything exported under `lib` (single owner)
  mcp.nix                 `packages.mcp-config` + the devshell command
  mcp-config.nix          the `lib.mkMcpConfig` function itself
  re-environment.nix      this repo's own `devShells.re`
  treefmt.nix             formatter configuration (`nix fmt`)
  update.nix              per-package update policy for `update-packages`
  update-packages.sh      the runner itself
packages/
  flake-module.nix        assembles all packages + `overlays.default`
  reexports.nix           overlay-only attributes surfaced in `packages`
  cpp/                    C/C++ packages
  go/                     Go packages
  misc/                   everything that is not a language package
  python/                 Python packages
  rust/                   Rust packages (built with crane)
overlays/                 overrides composed into `overlays.default`
modules/
  flake-module.nix        exports nixosModules / homeModules / flakeModules
  re-environment/         the RE shell, as a flake-parts module
toolsets/                 curated package groups, exported as `lib.toolsets`
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
   (`default.nix`).
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
[`nix/update.nix`](nix/update.nix) (`auto`, `manual`, `reexported`, or
`derived`).
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

## The RE environment

The lab's reverse-engineering tools are grouped into toolsets, and there are
three ways to take them.

`nix develop .#re` gives the whole thing here. In your own flake, either import
the module:

```nix
{
  inputs.seclab-pkgs.url = "github:Crypto-TII/seclab-pkgs";

  outputs = inputs@{ flake-parts, seclab-pkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ seclab-pkgs.flakeModules.default ];

      # All optional. `nixpkgs` defaults to ours, `shellName` to "re", and
      # every toolset to true.
      seclab.re = {
        nixpkgs = inputs.nixpkgs;
        toolsets.hardware = false;
      };
    };
}
```

or cherry-pick groups, which are plain `{ pkgs }` -> list functions:

```nix
devShells.default = pkgs.mkShell {
  packages =
    (seclab-pkgs.lib.toolsets.firmware { inherit pkgs; })
    ++ (seclab-pkgs.lib.toolsets.debugging { inherit pkgs; });
};
```

The groups are `binary-analysis`, `crypto`, `debugging`, `dev-tools`,
`firmware`, `forensics`, `hardware`, `python` and `reversing`;
`lib.mkToolsets { inherit pkgs; }` returns all of them as
`{ packagesByGroup, allPackages }`.

> A toolset needs `pkgs` built with **both** `overlays.default` and
> `config.allowUnfree = true` — it contains this repo's own packages, and
> ghidra-re and binwalk reach the unfree `dumpifs` through
> ghidraninja-ghidra-scripts. Both are asserted with an explanation rather
> than left to fail as `attribute 'ghidra-re' missing`.

The shell sets `GHIDRA_INSTALL_DIR`, `JAVA_HOME`, `PYTHONPATH` (for
`libtriton`) and, on x86_64, `DynamoRIO_DIR`.

`python` is nixpkgs' default interpreter. angr is the one exception — it needs
the python313 that [`overlays/angr-suite.nix`](overlays/angr-suite.nix)
patches, because nixpkgs' 3.14 build of it fails — so it comes as a separate
`angr-python` command rather than moving everything else back an interpreter.

## MCP configuration

`lib.mkMcpConfig` builds an MCP client config for the two servers this lab
runs — `mcp-reva`, pointed at `ghidra-re`, and Binary Ninja's headless
`binaryninja_mcp`. Nothing links it for you:

```sh
ln -sfn "$(mcp-config)" .mcp.json            # in the devshell
ln -sfn "$(nix build --no-link --print-out-paths .#mcp-config)" .mcp.json
```

From another flake, override the servers:

```nix
seclab-pkgs.lib.mkMcpConfig {
  inherit pkgs;                               # needs overlays.default
  extraServers.context7 = { type = "http"; url = "https://mcp.context7.com/mcp"; };
}
```

`binaryninja_mcp` is referenced by name, not by store path: it comes from the
licensed zip that `homeModules.binaryninja` builds with a per-user sha256, so
it resolves from `PATH` when that module is active.

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
