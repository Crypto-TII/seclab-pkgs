# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 Brian McGillion
{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  hatchling,
  hatch-vcs,
  cryptography,
  prettytable,
  versionCheckHook,
}:

buildPythonPackage (finalAttrs: {
  pname = "psptool";
  version = "3.6";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "PSPReverse";
    repo = "PSPTool";
    tag = finalAttrs.version;
    hash = "sha256-zvJwn4DPyvEvsfOYKRJJGUV4ZxT1Xl9xBzAGWCNeo+g=";
  };

  build-system = [
    hatchling
    hatch-vcs
  ];

  # hatch-vcs reads the version from git metadata the tarball lacks. psptool
  # reads it back through importlib.metadata at import, so a fallback would
  # not just mislabel the package, it would make `psptool -V` lie.
  env.HATCH_VCS_PRETEND_VERSION = finalAttrs.version;

  dependencies = [
    cryptography
    prettytable
  ];

  # tests/integration/fixtures is a submodule on an SSH remote, absent from
  # the tarball; without it the integration tests collect as errors.
  doCheck = false;

  pythonImportsCheck = [ "psptool" ];

  # The version is the one thing pythonImportsCheck cannot catch: importlib
  # succeeds with whatever hatchling wrote.
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "-V";
  doInstallCheck = true;

  meta = {
    description = "Display, extract and manipulate AMD PSP firmware inside UEFI images";
    homepage = "https://github.com/PSPReverse/PSPTool";
    license = lib.licenses.gpl3Plus;
    mainProgram = "psptool";
  };
})
