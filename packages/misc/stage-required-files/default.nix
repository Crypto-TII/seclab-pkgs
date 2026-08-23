# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# Bridges requiredFiles/ into the nix store for `pkgs.requireFile`.
# writeShellApplication so the script gets shellcheck at build time.
{
  writeShellApplication,
  git,
  nix,
}:

writeShellApplication {
  name = "stage-required-files";
  runtimeInputs = [
    git
    nix
  ];
  text = builtins.readFile ./stage-required-files.sh;
  meta = {
    description = "Stage requiredFiles/ vendor artifacts into the nix store for requireFile";
    mainProgram = "stage-required-files";
  };
}
