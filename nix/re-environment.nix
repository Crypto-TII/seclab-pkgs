# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{
  perSystem =
    { pkgs, ... }:
    {
      # The consumer-facing shell, built from this repo's own pkgs rather than by
      # importing our own flakeModule, which would instantiate nixpkgs twice.
      # `nix flake check` instantiates devShells without building them, so this
      # costs eval time only -- and it is what catches a toolset attribute that a
      # nixpkgs bump renamed, before a consumer does.
      devShells.re = import ../modules/re-environment/shell.nix {
        inherit pkgs;
        toolsets = import ../toolsets { inherit pkgs; };
      };
    };
}
