# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# Headless side of ReVa: a stdio MCP server that starts and manages Ghidra
# itself via PyGhidra.
#
# python313, not python3: angr and pwntools are not packaged for 3.14, and a
# shell using both this and angr needs one interpreter that can import both.
{
  lib,
  python313Packages,
}:

python313Packages.buildPythonApplication (finalAttrs: {
  pname = "reverse-engineering-assistant";
  version = "7.3.0";
  pyproject = true;

  src = python313Packages.fetchPypi {
    pname = "reverse_engineering_assistant";
    inherit (finalAttrs) version;
    hash = "sha256-vLJs7z5c8c5Zo86TFKpi+Rf+wIxODKm5txyUrDy5fSI=";
  };

  # setuptools_scm derives the version from git tags; the sdist has no .git.
  env.SETUPTOOLS_SCM_PRETEND_VERSION = finalAttrs.version;

  build-system = with python313Packages; [
    setuptools
    setuptools-scm
  ];

  dependencies = with python313Packages; [
    pyghidra
    mcp
    httpx
    httpx-sse
  ];

  doCheck = false; # its test suite needs a live Ghidra install
  pythonImportsCheck = [ "reva_cli" ];

  meta = {
    description = "ReVa headless MCP server (mcp-reva) for Ghidra";
    homepage = "https://github.com/cyberkaida/reverse-engineering-assistant";
    license = lib.licenses.asl20;
    mainProgram = "mcp-reva";
  };
})
