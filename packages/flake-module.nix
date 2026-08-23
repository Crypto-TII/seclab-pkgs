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
      pythonPackages = import ./python { inherit python3Packages; };
      rustPackages = import ./rust { inherit callPackage crane; };
    in
    cppPackages // goPackages // pythonPackages // rustPackages;
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages = mkSeclabPkgs {
        inherit pkgs;
        inherit (inputs) crane;
      };
    };

  # Overlay for use by downstream consumers
  flake.overlays.default =
    _final: prev:
    mkSeclabPkgs {
      pkgs = prev;
      inherit (inputs) crane;
    };
}
