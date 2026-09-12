# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
#
# dslite, cl2000 and dis2000 go on PATH via the wrapper rather than being
# runtimeInputs.
{
  lib,
  buildPythonPackage,
  setuptools,
  pytestCheckHook,
  pyyaml,
  c28x,
  uniflash,
  c2000-cgt,
  makeWrapper,
}:

buildPythonPackage (_finalAttrs: {
  pname = "f28335-tools";
  version = "0.1.0";
  pyproject = true;

  src = ./.;

  build-system = [ setuptools ];
  nativeBuildInputs = [ makeWrapper ];

  dependencies = [
    c28x
    pyyaml
  ];

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      c2000-cgt
      uniflash
    ])
  ];

  nativeCheckInputs = [ pytestCheckHook ];

  pythonImportsCheck = [
    "f28335_tools"
    "f28335_tools.cli"
  ];

  meta = {
    description = "Dump, reconstruct and stitch TMS320F28335 Flash/RAM/OTP/Boot-ROM via UniFlash + XDS200";
    homepage = "https://www.ti.com/product/TMS320F28335";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "f28335-tools";
  };
})
