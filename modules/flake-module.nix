# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ inputs, ... }:
{
  flake = {
    nixosModules.binaryninja = ./binaryninja/nixos.nix;
    nixosModules.freetoken = ./freetoken/nixos.nix;

    # Same partial application as the home-manager module below, so a consumer
    # importing it never threads our inputs through their own flake.
    flakeModules.default = import ./re-environment { seclabInputs = inputs; };

    # Partially applied so consumers need not thread flake inputs into their
    # home-manager scope.
    homeModules.binaryninja = import ./binaryninja/home.nix {
      inherit (inputs) nix-binary-ninja;
    };
  };
}
