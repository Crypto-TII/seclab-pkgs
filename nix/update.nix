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
      # No git tags at all upstream; the PyPI release is the only version
      # marker it publishes. fetchPypi emits a files.pythonhosted.org URL, and
      # nix-update's PyPI fetcher only matches the `pypi` netloc of a
      # mirror:// URL.
      biosutilities = [
        "--version=stable"
        "--url"
        "mirror://pypi/b/biosutilities/"
      ];

      # Main pin: v8 (2023) is the last release and upstream still commits, so
      # the tag feed is three years stale. Only `src` moves -- the binexport
      # rev and the abseil/protobuf/sqlite archives beside it are
      # hand-maintained, and a bump needing them in step fails the build rather
      # than passing quietly.
      bindiff = [
        "--version=branch"
        "-vr"
        "v?([0-9].*)"
      ];

      # Main pin, and the one place the BinExport rev lives: bumping this also
      # moves the tree bindiff's CMake build compiles against. deps.json has to
      # be regenerated alongside it, with the package's own
      # `mitmCache.updateScript`.
      ghidra-binexport = [
        "--version=branch"
        "-vr"
        "v?([0-9].*)"
      ];

      # Two tag streams: the weekly cronbuild-* and the dormant, hand-cut
      # release_*. Matching cronbuild only keeps a version sort from flipping
      # between them, and skips the malformed release_7.91.18308B/C tags.
      dynamorio = [
        "--version=stable"
        "-vr"
        "cronbuild-([0-9.]+)"
      ];

      # Master pin: the last tag is v0.9 (2022), ~800 commits behind. Same
      # shape as proploader -- the regex keeps a non-numeric tag from winning.
      libtriton = [
        "--version=branch"
        "-vr"
        "v?([0-9].*)"
      ];

      # No src: ft-launcher.sh installs `freetoken[accel]==<version>` at run
      # time, so the version is a pip requirement and must track PyPI, not the
      # git tags -- those carry a moving `nightly` and can precede the wheel.
      freetoken = [
        "--version=stable"
        "--url"
        "mirror://pypi/f/freetoken/"
      ];

      # No GitHub releases, so nix-update falls back to the tag feed -- which
      # still carries 3.2.dev0. The anchors keep that prerelease out of the
      # version sort.
      psptool = [
        "--version=stable"
        "-vr"
        "^([0-9.]+)$"
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

    # Bumped by whoever owns them -- nixpkgs, or an input's overlay. Read from
    # the data file so adding a re-export cannot leave a ghost entry here.
    reexported = lib.attrNames (import ../packages/reexports.nix);

    # Nothing of their own to bump.
    derived = [
      # keep-sorted start
      "f28335-tools"
      "ghidra-re"
      "mcp-config"
      "stage-required-files"
      # keep-sorted end
    ];
  };

  classified =
    lib.attrNames policy.auto ++ lib.attrNames policy.manual ++ policy.reexported ++ policy.derived;

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
            Add each to exactly one of policy.auto / manual / reexported / derived.
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
          text = builtins.replaceStrings [ "@autoCalls@" "@manualBlock@" ] [ autoCalls manualBlock ] (
            builtins.readFile ./update-packages.sh
          );
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
