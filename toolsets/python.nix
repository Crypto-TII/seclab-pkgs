# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ pkgs }:
let
  seclab = import ./lib.nix { inherit pkgs; };
in
seclab.requireSeclabPkgs [
  (pkgs.python3.withPackages (
    ps: with ps; [
      # keep-sorted start
      angr
      c28x
      cantools
      capstone
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
      python-registry
      r2pipe
      requests
      ropper
      unicorn
      yara-python
      z3-solver
      # keep-sorted end
      # angrcli is missing on purpose: it fails pythonMetadataCheckPhase in
      # this pin, declaring 1.3.0 against .dist-info metadata that says 1.2.0.
      # claripy is gone from nixpkgs: angr 10 absorbed it, and it is reached as
      # angr.claripy rather than a top-level module.
    ]
  ))
]
