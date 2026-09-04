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
  config,
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

  # Python packages required by Binary Ninja plugins.
  #
  # svd2py comes from this flake's overlays.default, which this module
  # therefore depends on.
  pluginPythonDeps = with pkgs.python3Packages; [
    click
    httpx
    jinja2
    markdown-it-py
    networkx
    numpy
    orjson
    psutil
    pydantic
    pygments
    pyyaml
    requests
    sqlite-vec
    pkgs.svd2py
  ];

  # nix-binary-ninja only publishes an x86_64-linux build.
  supported = pkgs.stdenv.hostPlatform.system == "x86_64-linux";

  # Sidekick's remaining pip set, resolved into a venv rather than packaged.
  binjaDir = "${config.home.homeDirectory}/.binaryninja";
  venvDir = "${binjaDir}/venv";
  sitePackages = "${venvDir}/lib/python${pkgs.python3.pythonVersion}/site-packages";
  settingsFile = "${binjaDir}/settings.json";

  sidekickVenvSync = pkgs.writeShellApplication {
    name = "binaryninja-venv-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      stamp="${venvDir}/.nix-python"

      if [ "$(cat "$stamp" 2>/dev/null || true)" != "${pkgs.python3}" ] ||
        [ ! -x "${venvDir}/bin/python" ]; then
        echo "recreating venv for ${pkgs.python3}"
        rm -rf "${venvDir}"
        "${pkgs.python3}/bin/python3" -m venv "${venvDir}"
        "${venvDir}/bin/pip" install --disable-pip-version-check ${lib.escapeShellArgs cfg.sidekick.pipPackages}
        printf '%s' "${pkgs.python3}" >"$stamp"
      else
        echo "venv already current for ${pkgs.python3}"
      fi

      # settings.json is Binary Ninja's own file, written by its GUI, so merge
      # the one key rather than replacing the document.
      mkdir -p "${binjaDir}"
      [ -f "${settingsFile}" ] || echo '{}' >"${settingsFile}"
      tmp="$(mktemp)"
      jq --arg sp "${sitePackages}" '. + {"python.virtualenv": $sp}' "${settingsFile}" >"$tmp"
      mv "$tmp" "${settingsFile}"
    '';
  };
in
{
  # Implication rather than a bare check: a consumer who imports this module
  # but never enables Binary Ninja has no reason to need the overlay.
  assertions = [
    {
      assertion = cfg.enable -> (pkgs ? svd2py);
      message = ''
        homeModules.binaryninja needs seclab-pkgs' overlays.default applied to
        the pkgs home-manager uses: it pulls pkgs.svd2py into the Binary Ninja
        plugin PYTHONPATH.

        Add it where you build nixpkgs, e.g.

          nixpkgs.overlays = [ inputs.seclab-pkgs.overlays.default ];

        With home-manager.useGlobalPkgs that is the same pkgs as the NixOS one;
        without it, apply the overlay in the home-manager scope as well.
      '';
    }
  ];

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
          # Vendored rather than fetched: the upstream URL is unversioned and
          # its content already changed once, breaking the pinned hash.
          cp ${./logo.png} $out/share/pixmaps/binaryninja.png
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

  # Sidekick resolves these at runtime; `systemd.user.startServices` restarts
  # this unit whenever the embedded python store path changes, which is what
  # makes the venv self-healing across nixpkgs bumps.
  systemd.user.services.binaryninja-venv = lib.mkIf (cfg.enable && cfg.sidekick.enable && supported) {
    Unit.Description = "Binary Ninja Sidekick venv";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe sidekickVenvSync;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
