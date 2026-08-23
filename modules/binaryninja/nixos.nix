# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
# Binary Ninja - reverse engineering platform
#
# Options only. The install lives in the matching home-manager module
# (homeModules.binaryninja), which reads these through osConfig.
#
# Usage:
#   features.development.binaryninja = {
#     enable = true;
#     sha256 = "<base32 of your binaryninja_linux_dev_ultimate.zip>";
#   };
{
  config,
  lib,
  ...
}:
let
  cfg = config.features.development.binaryninja;
in
{
  options.features.development.binaryninja = {
    enable = lib.mkEnableOption "Binary Ninja reverse engineering platform";

    sha256 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "03ivd2iv9pa5xqw703aa46fzscb5shsxwj15vqwp6f6sj5kcpvaq";
      description = ''
        base32 sha256 of your binaryninja_linux_dev_ultimate.zip.

        Consumer-supplied rather than pinned here: the licensed build differs
        per user, so a shared pin would force everyone onto one exact
        dev-ultimate download.

        Obtain it by dropping the zip into the seclab-pkgs requiredFiles/
        directory and running `stage-required-files`, which also puts the
        artifact where requireFile can find it.

        Nullable so that merely importing this module does not oblige every
        host to carry a Binary Ninja licence; it is only required when
        `enable` is set, which the assertion below enforces.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.sha256 != null;
        message = ''
          features.development.binaryninja.enable is on but sha256 is unset.
          Drop binaryninja_linux_dev_ultimate.zip into seclab-pkgs'
          requiredFiles/ and run `stage-required-files` to get the hash.
        '';
      }
    ];
  };
}
