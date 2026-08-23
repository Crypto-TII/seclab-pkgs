# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# NixOS and home-manager modules for packages that need more than an overlay
# entry -- currently Binary Ninja, whose install is a set of overrides rather
# than a standalone derivation.
{ inputs, ... }:
{
  flake = {
    nixosModules.binaryninja = ./binaryninja/nixos.nix;

    # Partially applied so the module does not depend on the consumer threading
    # flake inputs into their home-manager scope.
    homeModules.binaryninja = import ./binaryninja/home.nix {
      inherit (inputs) nix-binary-ninja;
    };
  };
}
