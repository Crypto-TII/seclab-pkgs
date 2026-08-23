# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# NixOS and home-manager modules for packages that need more than an overlay
# entry -- currently Binary Ninja, whose install is a set of overrides on an
# upstream package rather than a standalone derivation, and which needs the
# consumer's own sha256.
#
# These are a separate output kind from overlays.default: an overlay produces
# package attributes, a module produces options and config.
#
# homeModules.binaryninja ALSO REQUIRES overlays.default to be applied to the
# pkgs home-manager uses -- it puts pkgs.svd2py on the plugin PYTHONPATH. The
# module asserts this, so a missing overlay fails at evaluation with a message
# rather than at build time with a missing attribute.
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
