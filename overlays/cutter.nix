# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# qtbase 6.12 made uic validate custom widget class names, and Cutter 2.5.0's
# .ui files declare the template `AddressableItemList<>`, so autouic rejects
# them before anything compiles. Upstream swaps in a non-template alias:
# rizinorg/cutter#3670. Drop once a release nixpkgs carries has it.
#
# Through stdenv rather than overrideAttrs: passthru.withPlugins closes over the
# let-bound derivation in cutter's own package.nix, so overrideAttrs patches the
# bare build and leaves the wrapper -- the thing toolsets/reversing.nix uses --
# still pointing at the unpatched one.
final: prev: {
  cutter = prev.cutter.override {
    stdenv = prev.stdenv // {
      mkDerivation =
        args:
        prev.stdenv.mkDerivation (
          args
          // {
            patches = (args.patches or [ ]) ++ [
              (final.fetchpatch {
                name = "cutter-uic-addressable-item-list-view.patch";
                url = "https://github.com/rizinorg/cutter/commit/bfb65782c0b3e4df4e2f0e4f5284c51848bb8358.patch";
                hash = "sha256-qhkGX+yr2Tn9twfwk6XWiiPlFpwdjMy7YNofywL9gvY=";
              })
            ];
          }
        );
    };
  };
}
