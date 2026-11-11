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
        overlays = [
          self.overlays.default
          # sphinx-hook.sh reads sphinxBuilders with `eval "(...)"`, which under
          # structuredAttrs -- now the stdenv default -- sees only the first
          # element of the list, so the `man` builder never runs and reuse's
          # declared man output goes unproduced. A string restores the whole
          # list. Drop once the hook handles structuredAttrs.
          (_final: prev: {
            reuse = prev.reuse.overridePythonAttrs (_: {
              sphinxBuilders = "html man";
            });
          })
        ];
      };
    };
}
