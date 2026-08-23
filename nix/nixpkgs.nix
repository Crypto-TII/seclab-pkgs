# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# The perSystem `pkgs`, carrying this flake's own overlay.
#
# Applied here so perSystem.packages can resolve intra-repo dependencies:
# packages/misc/f28335-dump takes `uniflash` as an argument, and a plain
# nixpkgs has no such attribute.
#
# allowUnfree because uniflash and stm32cubeprogrammer are vendor blobs under
# proprietary licences. Both are kept out of perSystem.packages by ciExclude in
# packages/flake-module.nix, but f28335-dump wraps uniflash and so needs it.
{ inputs, self, ... }:
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ self.overlays.default ];
      };
    };
}
