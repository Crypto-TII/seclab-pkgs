# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
#
# Installs Binary Ninja when features.development.binaryninja.enable is set by
# the NixOS side (nixosModules.binaryninja).
#
# `nix-binary-ninja` is partially applied at export time rather than read from a
# module argument, so this works regardless of whether the consumer threads
# flake inputs into their home-manager scope.
{ nix-binary-ninja }:

{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = osConfig.features.development.binaryninja;

  # Binary Ninja ships as an out-of-tree zip that cannot be a flake input: a
  # missing file would break `nix flake update` on every host, including those
  # that never install it. requireFile keeps it out of flake evaluation
  # entirely -- it is only forced when something actually builds this.
  #
  # Provision the zip once per host by dropping it in seclab-pkgs'
  # requiredFiles/ and running `stage-required-files`.
  binaryninja-src = pkgs.requireFile {
    name = "binaryninja_linux_dev_ultimate.zip";
    inherit (cfg) sha256;
    message = ''
      Binary Ninja source zip is not in the Nix store. Drop it into
      seclab-pkgs' requiredFiles/ and run `stage-required-files`, or add it
      directly with:
        nix-store --add-fixed sha256 <path>/binaryninja_linux_dev_ultimate.zip
    '';
  };

  # Python packages required by Binary Ninja plugins. svd2py comes from this
  # same flake's overlay.
  pluginPythonDeps = with pkgs.python3Packages; [
    click
    pyyaml
    pkgs.svd2py
  ];

  # nix-binary-ninja only publishes an x86_64-linux build.
  supported = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
in
{
  # Not using nix-binary-ninja's own hmModules.binaryninja: it sets
  # nixpkgs.overlays in the home-manager scope, which is incompatible with
  # home-manager.useGlobalPkgs. Add the package directly instead.
  home.packages = lib.optionals (cfg.enable && supported) [
    (
      (nix-binary-ninja.packages.x86_64-linux.binary-ninja-ultimate.override {
        overrideSource = binaryninja-src;
      }).overrideAttrs
      (_old: {
        # Binary Ninja bundles Qt 6.10.1, which is incompatible with the nixpkgs
        # Qt 6.10.2 platform plugins injected by wrapQtAppsHook. Replace the
        # installPhase to:
        # 1. Keep the bundled Qt .so files (skip the find -delete)
        # 2. Not pass qtWrapperArgs to makeWrapper (avoids a mismatched
        #    QT_PLUGIN_PATH)
        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin
          mkdir -p $out/opt/binaryninja
          mkdir -p $out/share/pixmaps
          cp -r * $out/opt/binaryninja
          cp ${
            pkgs.fetchurl {
              url = "https://docs.binary.ninja/img/logo.png";
              hash = "sha256-TzGAAefTknnOBj70IHe64D6VwRKqIDpL4+o9kTw0Mn4=";
            }
          } $out/share/pixmaps/binaryninja.png
          chmod +x $out/opt/binaryninja/binaryninja
          buildPythonPath "$pythonDeps"
          pluginPythonPath="${pkgs.python3.pkgs.makePythonPath pluginPythonDeps}"
          makeWrapper $out/opt/binaryninja/binaryninja $out/bin/binaryninja \
            --prefix PYTHONPATH : "$program_PYTHONPATH:$pluginPythonPath"

          runHook postInstall
        '';
      })
    )
  ];
}
