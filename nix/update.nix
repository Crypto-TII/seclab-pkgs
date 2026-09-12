# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# `update-packages` -- the half of dependency maintenance that `nix flake
# update` does not do.
#
{ lib, ... }:
let
  # Every package must appear in exactly one bucket, or evaluation fails.
  policy = {
    # nix-update targets; the value is its extra argv. Every flag is load-bearing.
    auto = {
      # No src: ft-launcher.sh installs `freetoken[accel]==<version>` at run
      # time, so the version is a pip requirement and must track PyPI, not the
      # git tags -- those carry a moving `nightly` and can precede the wheel.
      freetoken = [
        "--version=stable"
        "--url"
        "mirror://pypi/f/freetoken/"
      ];

      # Unanchored on purpose: without a regex nix-update picks the non-numeric
      # `last-support-for-xbee-s6b` tag, and `^([0-9].*)` drops `v1.0-37`.
      proploader = [
        "--version=branch"
        "-vr"
        "v?([0-9].*)"
      ];

      # fetchPypi emits a files.pythonhosted.org URL; nix-update's PyPI fetcher
      # only matches the `pypi` netloc of a mirror:// URL.
      svd2py = [
        "--version=stable"
        "--url"
        "mirror://pypi/s/svd2py/"
      ];
    };

    # Vendor portals, no feed to poll.
    manual = {
      stm32cubeprogrammer = "https://www.st.com/en/development-tools/stm32cubeprog.html";
      uniflash = "https://www.ti.com/tool/UNIFLASH";
    };

    # Temporary overrides, dropped once nixpkgs catches up.
    pinned = {
      mcp-reva = "placeholder until nixpkgs ships ReVa";
      reva-ghidra-extension = "asset must match the nixpkgs ghidra series";
    };

    # Nothing of their own to bump.
    derived = [
      # keep-sorted start
      "f28335-tools"
      "ghidra-re"
      "stage-required-files"
      # keep-sorted end
    ];
  };

  classified =
    lib.attrNames policy.auto
    ++ lib.attrNames policy.manual
    ++ lib.attrNames policy.pinned
    ++ policy.derived;

  # Not packages.
  notPackages = [
    "override"
    "overrideDerivation"
  ];

  autoCalls = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: args: "run_update ${lib.escapeShellArgs ([ name ] ++ args)}") policy.auto
  );
in
{
  perSystem =
    {
      pkgs,
      self',
      ...
    }:
    let
      defined = lib.subtractLists notPackages (lib.attrNames self'.packages);
      unclassified = lib.subtractLists classified defined;
      ghosts = lib.subtractLists defined classified;

      # At eval, so `nix flake check` catches an unclassified package.
      guard =
        value:
        lib.throwIf (unclassified != [ ])
          ''
            nix/update.nix: no update policy for ${lib.concatStringsSep ", " unclassified}.
            Add each to exactly one of policy.auto / manual / pinned / derived.
          ''
          (
            lib.throwIf (ghosts != [ ]) ''
              nix/update.nix: policy names packages that no longer exist: ${lib.concatStringsSep ", " ghosts}.
              Remove them from policy.
            '' value
          );

      describe = name: lib.getVersion self'.packages.${name};
      manualBlock = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: url: "  ${name} ${describe name} -- ${url}") policy.manual
      );
      pinnedBlock = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: why: "  ${name} ${describe name} -- ${why}") policy.pinned
      );

      updatePackages = guard (
        pkgs.writeShellApplication {
          name = "update-packages";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.git
            pkgs.gnugrep
            pkgs.nix-update
            # so a forwarded --format works
            pkgs.nixfmt
          ];
          # readFile of a source path, not a derivation: this flake sets
          # allow-import-from-derivation = false.
          text =
            builtins.replaceStrings
              [ "@autoCalls@" "@manualBlock@" "@pinnedBlock@" ]
              [ autoCalls manualBlock pinnedBlock ]
              (builtins.readFile ./update-packages.sh);
          meta = {
            description = "Bump the package version pins that `nix flake update` cannot see";
            mainProgram = "update-packages";
          };
        }
      );
    in
    {
      apps.update-packages = {
        type = "app";
        program = lib.getExe updatePackages;
        meta.description = "Bump the package version pins that `nix flake update` cannot see";
      };

      devshells.default.commands = [
        {
          name = "update-packages";
          category = "maintenance";
          help = "bump package version pins that `nix flake update` cannot see";
          command = ''exec ${lib.getExe updatePackages} "$@"'';
        }
      ];
    };
}
