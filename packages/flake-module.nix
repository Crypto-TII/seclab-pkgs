# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
let
  # `import`, not `callPackage`, for the category dirs: the attribute names must
  # be statically known or composing this overlay with others recurses forever.
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
in
{
  # Unfiltered; heavy packages are held back in nix/exclusions.nix.
  perSystem =
    { pkgs, ... }:
    {
      packages = mkSeclabPkgs {
        inherit pkgs;
        inherit (inputs) crane;
      };
    };

  # Through `final`, not `prev`: f28335-tools takes uniflash, which this same
  # overlay contributes. Composed, so consumers get c28x from one overlay.
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
