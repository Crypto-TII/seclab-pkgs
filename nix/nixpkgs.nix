# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ inputs, self, ... }:
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        # uniflash and stm32cubeprogrammer are proprietary, and f28335-tools
        # wraps uniflash.
        config.allowUnfree = true;
        # Lets perSystem.packages resolve intra-repo deps: f28335-tools takes
        # uniflash as an argument, which a plain nixpkgs has no attribute for.
        overlays = [ self.overlays.default ];
      };
    };
}
