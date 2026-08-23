# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
let
  # Build all seclab packages given a pkgs set.
  # This function is reused by both perSystem.packages and the overlay.
  #
  # Uses `import` instead of `callPackage` for the category directories so that
  # the resulting attrset has statically-known attribute names.  This keeps the
  # overlay lazy: nixpkgs's fixed-point can determine which names the overlay
  # contributes without forcing `pkgs.callPackage` (which would cause infinite
  # recursion when the overlay is composed with other overlays).
  mkSeclabPkgs =
    { pkgs, crane }:
    let
      inherit (pkgs) callPackage python3Packages;

      cppPackages = import ./cpp { inherit callPackage; };
      goPackages = import ./go { inherit callPackage; };
      miscPackages = import ./misc { inherit callPackage; };
      pythonPackages = import ./python { inherit python3Packages; };
      rustPackages = import ./rust { inherit callPackage crane; };
    in
    cppPackages // goPackages // miscPackages // pythonPackages // rustPackages;

  # nix/checks.nix turns every entry in perSystem.packages into a
  # `package-<name>` check. Exclude large bin wrappers.
  ciExclude = [
    # keep-sorted start
    # Ghidra plus seven extensions -- far too heavy for every CI run.
    "ghidra-re"
    "stm32cubeprogrammer"
    "uniflash"
    # keep-sorted end
  ];
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages = removeAttrs (mkSeclabPkgs {
        inherit pkgs;
        inherit (inputs) crane;
      }) ciExclude;
    };

  # Overlay for use by downstream consumers.
  #
  # Resolves through `final`, not `prev`: misc/f28335-dump takes `uniflash` as
  # an argument and uniflash is contributed by this same overlay, so `prev`
  # would not have it.
  # Composed, not bare: f28335-dump's classifier needs python3Packages.c28x,
  # so carrying tms320c28x-re's overlay here keeps this one self-contained --
  # downstream consumers add a single overlay and get everything.
  flake.overlays.default = inputs.nixpkgs.lib.composeManyExtensions [
    (import ../overlays/angr-suite.nix)
    inputs.tms320c28x-re.overlays.default
    (
      final: _prev:
      mkSeclabPkgs {
        pkgs = final;
        inherit (inputs) crane;
      }
    )
  ];
}
