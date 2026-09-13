# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# The shell body, shared by the exported flakeModule and this repo's own
# devShells.re, so the two cannot drift.
{
  pkgs,
  toolsets,
  extraPackages ? [ ],
}:
let
  inherit (pkgs) lib;
in
pkgs.mkShell (
  {
    name = "seclab-re";

    packages = toolsets.allPackages ++ extraPackages;

    # pyghidra, and every `gradle -PGHIDRA_INSTALL_DIR` build, read this.
    # ghidra-re rather than plain ghidra: it is the one carrying the extensions.
    GHIDRA_INSTALL_DIR = "${pkgs.ghidra-re}/lib/ghidra";

    # jpype dlopens libjvm from here, and ghidra is built against openjdk21, so
    # another JDK loads a JVM the extensions were not compiled for.
    JAVA_HOME = pkgs.openjdk21.home;

    # libtriton deliberately does not propagate its site-packages; this is the
    # consumer that has to. Same interpreter as every other python tool here,
    # so nothing needs reordering or resetting.
    PYTHONPATH = "${pkgs.libtriton}/${pkgs.python3.sitePackages}";
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
    # DynamoRIOConfig.cmake lives here; clients set -DDynamoRIO_DIR to find it.
    DynamoRIO_DIR = "${pkgs.dynamorio}/cmake";
  }
)
