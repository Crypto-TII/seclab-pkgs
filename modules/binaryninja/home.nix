# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
#
# nix-binary-ninja is partially applied at export time so this works whether or
# not the consumer threads flake inputs into their home-manager scope.
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

  # requireFile, not a flake input: a missing zip would otherwise break
  # `nix flake update` on every host, including those that never install it.
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

  # svd2py comes from overlays.default, which this module therefore depends on.
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

  # Same makePythonPath as the wrapper, so the venv and wrapper cannot diverge.
  pluginDepsPth = pkgs.writeText "nix-plugin-deps.pth" (
    lib.replaceStrings [ ":" ] [ "\n" ] (pkgs.python3.pkgs.makePythonPath pluginPythonDeps) + "\n"
  );

  sidekickVenvSync = pkgs.writeShellApplication {
    name = "binaryninja-venv-sync";
    runtimeInputs = [ pkgs.coreutils ];
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

      # A venv is isolated, so inject the closure via a .pth. Rewritten every
      # run: the stamp tracks python, but these paths move when any dep does.
      install -Dm644 "${pluginDepsPth}" "${sitePackages}/nix-plugin-deps.pth"
    '';
  };

  # An empty set means nothing to sync and no unit is defined.
  settingsPatch =
    lib.optionalAttrs cfg.sidekick.enable { "python.virtualenv" = sitePackages; }
    // lib.optionalAttrs cfg.mcp.enable { "ui.mcp.enabled" = true; };

  # One writer: per-feature units would race on the same read-modify-write.
  settingsSync = pkgs.writeShellApplication {
    name = "binaryninja-settings-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      # Binary Ninja's GUI writes this file too, so merge rather than replace.
      mkdir -p "${binjaDir}"
      [ -f "${settingsFile}" ] || echo '{}' >"${settingsFile}"
      tmp="$(mktemp)"
      jq --argjson patch ${lib.escapeShellArg (builtins.toJSON settingsPatch)} '. + $patch' \
        "${settingsFile}" >"$tmp"
      mv "$tmp" "${settingsFile}"
    '';
  };
in
{
  # Implication: importing without enabling needs no overlay.
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

  # Not nix-binary-ninja's hmModules.binaryninja: it sets nixpkgs.overlays in the
  # home-manager scope, which is incompatible with home-manager.useGlobalPkgs.
  home.packages = lib.optionals (cfg.enable && supported) [
    (
      (nix-binary-ninja.packages.x86_64-linux.binary-ninja-ultimate.override {
        overrideSource = binaryninja-src;
      }).overrideAttrs
        (_old: {
          # The bundled Qt 6.10.1 is incompatible with the nixpkgs 6.10.2 plugins
          # wrapQtAppsHook injects, so keep the bundled .so files and drop
          # qtWrapperArgs.
          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            mkdir -p $out/opt/binaryninja
            mkdir -p $out/share/pixmaps
            cp -r * $out/opt/binaryninja
            # Vendored: the upstream URL is unversioned and already changed once.
            cp ${./logo.png} $out/share/pixmaps/binaryninja.png
            chmod +x $out/opt/binaryninja/binaryninja
            buildPythonPath "$pythonDeps"
            pluginPythonPath="${pkgs.python3.pkgs.makePythonPath pluginPythonDeps}"
            makeWrapper $out/opt/binaryninja/binaryninja $out/bin/binaryninja \
              --prefix PYTHONPATH : "$program_PYTHONPATH:$pluginPythonPath"

            # Upstream leaves the headless MCP server in opt/, so nothing can spawn
            # it by name. Same PYTHONPATH as the GUI: it loads the same plugins.
            if [ -f $out/opt/binaryninja/binaryninja_mcp ]; then
              chmod +x $out/opt/binaryninja/binaryninja_mcp
              makeWrapper $out/opt/binaryninja/binaryninja_mcp $out/bin/binaryninja_mcp \
                --prefix PYTHONPATH : "$program_PYTHONPATH:$pluginPythonPath"
            else
              echo "note: this Binary Ninja zip has no binaryninja_mcp; headless MCP unavailable"
            fi

            runHook postInstall
          '';
        })
    )
  ];

  # systemd.user.startServices restarts this when the python store path moves,
  # which is what makes the venv self-healing across nixpkgs bumps.
  systemd.user.services.binaryninja-venv = lib.mkIf (cfg.enable && cfg.sidekick.enable && supported) {
    Unit.Description = "Binary Ninja Sidekick venv";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe sidekickVenvSync;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.binaryninja-settings =
    lib.mkIf (cfg.enable && supported && settingsPatch != { })
      {
        Unit = {
          Description = "Binary Ninja settings owned by nix";
          # python.virtualenv should not name a venv that does not exist yet.
          After = [ "binaryninja-venv.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe settingsSync;
        };
        Install.WantedBy = [ "default.target" ];
      };
}
