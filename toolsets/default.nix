# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# `enabled` is keyed by group name, not nine enable<Group> arguments: the group
# names are kebab-case and the mapping to camelCase is a bug waiting to happen.
{
  pkgs,
  enabled ? { },
}:
let
  inherit (pkgs) lib;

  groups = import ./groups.nix;

  # Every group, whatever `enabled` says: a consumer who turned a group off in
  # the shell can still reach it by name.
  packagesByGroup = {
    # keep-sorted start
    binary-analysis = import ./binary-analysis.nix { inherit pkgs; };
    crypto = import ./crypto.nix { inherit pkgs; };
    cross = import ./cross.nix { inherit pkgs; };
    cross-extra = import ./cross-extra.nix { inherit pkgs; };
    debugging = import ./debugging.nix { inherit pkgs; };
    dev-tools = import ./dev-tools.nix { inherit pkgs; };
    firmware = import ./firmware.nix { inherit pkgs; };
    forensics = import ./forensics.nix { inherit pkgs; };
    hardware = import ./hardware.nix { inherit pkgs; };
    python = import ./python.nix { inherit pkgs; };
    reversing = import ./reversing.nix { inherit pkgs; };
    static-analysis = import ./static-analysis.nix { inherit pkgs; };
    # keep-sorted end
  };
in
# groups.nix repeats these names, with their defaults, for the re-environment
# module, which declares one option per group and has no pkgs to ask.
assert lib.assertMsg (lib.attrNames packagesByGroup == lib.attrNames groups) ''
  toolsets/groups.nix and toolsets/default.nix disagree:
    groups.nix:  ${lib.concatStringsSep " " (lib.attrNames groups)}
    default.nix: ${lib.concatStringsSep " " (lib.attrNames packagesByGroup)}
'';
{
  inherit packagesByGroup;

  allPackages = lib.concatLists (
    lib.mapAttrsToList (
      group: packages: lib.optionals (enabled.${group} or groups.${group}) packages
    ) packagesByGroup
  );
}
