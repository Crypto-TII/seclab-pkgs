# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 Brian McGillion
#
# Upstream cuts no git tags; PyPI is the only version marker it publishes, and
# 25.7.1 is the "BIOSUtilities v25.07.01" commit.
{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  dissect-util,
  pefile,
  makeWrapper,
  _7zz,
  uefitool,
}:

buildPythonPackage (finalAttrs: {
  pname = "biosutilities";
  version = "25.7.1";
  pyproject = true;

  src = fetchPypi {
    inherit (finalAttrs) pname version;
    hash = "sha256-1+zOHPjJz/XtORy+5MzHCoauX5IT5AaBUSG+QX/yzY0=";
  };

  build-system = [ setuptools ];
  nativeBuildInputs = [ makeWrapper ];

  # Declared as extras upstream, but common/executables.py imports pefile at
  # module scope and __main__ imports every extractor, so `--help` alone dies
  # without them.
  dependencies = [
    dissect-util
    pefile
  ];

  # Upstream pins dissect.util==3.20 and pefile==2023.2.7; this pin ships 3.24
  # and 2024.8.26. Stops the installed metadata advertising versions that are
  # not in the closure.
  pythonRelaxDeps = [
    "dissect.util"
    "pefile"
  ];

  # common/externals.py resolves these with shutil.which and raises at
  # extraction time, not import time. TianoCompress and comextract are not in
  # nixpkgs, so the AMI PFAT, Phoenix TDK and Toshiba paths stay unavailable.
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      _7zz
      uefitool
    ])
  ];

  doCheck = false; # no tests upstream

  # __main__ pulls in every extractor, which is what proves the two runtime
  # deps resolve; a bare `import biosutilities` does not.
  pythonImportsCheck = [
    "biosutilities"
    "biosutilities.__main__"
  ];

  meta = {
    description = "Extractors for AMI, Insyde, Phoenix, Award, Dell, Apple and OEM BIOS/UEFI capsules";
    homepage = "https://github.com/platomav/BIOSUtilities";
    license = lib.licenses.bsd2Patent;
    mainProgram = "biosutilities";
  };
})
