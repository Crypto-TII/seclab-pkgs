# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ pkgs }:
let
  seclab = import ./lib.nix { inherit pkgs; };

  # angr alone cannot use the default interpreter: overlays/angr-suite.nix
  # patches python313 because nixpkgs' 3.14 angr does not build, its expression
  # predating the Rust extension. Everything else here, angr's own claripy and
  # pypcode included, is fine on python3 -- so the exception gets its own
  # command rather than moving the whole environment back an interpreter.
  angr-python = pkgs.writeShellScriptBin "angr-python" ''
    # Unset, not inherited: a shell holding these tools has PYTHONPATH stacked
    # with python3 site-packages, and a 3.13 interpreter cannot load extension
    # modules built for 3.14. Sealing it keeps the exception to this command.
    exec env -u PYTHONPATH ${pkgs.python313.withPackages (ps: [ ps.angr ])}/bin/python "$@"
  '';
in
seclab.requireSeclabPkgs [
  (pkgs.python3.withPackages (
    ps: with ps; [
      # keep-sorted start
      c28x
      cantools
      capstone
      claripy
      construct
      frida-python
      intelhex
      ipython
      kaitaistruct
      keystone-engine
      lief
      mcp
      pefile
      pwntools
      pycryptodome
      pyelftools
      pyghidra
      pylink-square
      pypcode
      pyserial
      python-can
      r2pipe
      requests
      ropper
      unicorn
      yara-python
      z3-solver
      # keep-sorted end
      # angrcli and python-registry are missing on purpose: both fail
      # pythonMetadataCheckPhase in this pin, declaring 1.3.0 and 1.4 against
      # .dist-info metadata that says 1.2.0 and 1.3.1.
    ]
  ))
  angr-python
]
