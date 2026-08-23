# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
#
# Dumps Flash, RAM, Boot ROM, OTP and peripheral frames from a TMS320F28335 via
# TI UniFlash's dslite CLI over an XDS200 USB JTAG probe, rebuilds the dump into
# a linkable COFF + disassembly, and stitches it into a single 8 MiB chip image
# for Binary Ninja.
#
# Replaces the three writeShellApplication entry points this used to ship
# (dump_f28335 / reconstruct_f28335 / stitch_f28335) with one program and three
# subcommands. The external tools it drives -- dslite from uniflash, cl2000 and
# dis2000 from c2000-cgt -- are put on PATH by the wrapper rather than being
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
