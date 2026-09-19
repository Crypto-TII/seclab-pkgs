# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# Held out of CI checks and/or the devshell. These stay in perSystem.packages,
# so `nix build .#<name>` and nix/update.nix still see them.
{
  checks = [
    # keep-sorted start
    # Builds abseil and protobuf from source alongside the differ: 38s on 128
    # cores, so ~20 minutes on a four-vCPU runner.
    "bindiff"
    # Half-hour from-source build behind a submodule fetch.
    "dynamorio"
    # Unfree CUDA 13 closure, and the derivation is only the FHS sandbox.
    "freetoken"
    # A Gradle build against the whole Ghidra distribution.
    "ghidra-binexport"
    # Ghidra plus eight extensions.
    "ghidra-re"
    # ~19k lines of generated semantics in one TU at -O3, plus LLVM.
    "libtriton"
    # GHIDRA_INSTALL_DIR carries store context, so it build-depends on
    # ghidra-re, which is excluded right above.
    "mcp-config"
    # A uv2nix venv from a foreign nixpkgs; CI has no pwndbg.cachix.org, so a
    # miss builds gdb, lldb and ~40 sdists from source.
    "pwndbg"
    "pwndbg-lldb"
    # requireFile behind an ST login.
    "stm32cubeprogrammer"
    # Large vendor installer from TI.
    "uniflash"
    # keep-sorted end
  ];

  devshell = [
    # keep-sorted start
    # packagesFrom takes build inputs, and angr's are rustc, cargo and cmake.
    "angr"
    "c28x"
    # buildRustPackage lists both cargo and the auditable-cargo wrapper, and
    # both ship bin/cargo, so buildEnv refuses the merge.
    "c28xdec"
    "freetoken"
    "ghidra-binexport"
    "ghidra-re"
    "mcp-config"
    # Would put a second nixpkgs' cc-wrapper and setup hooks on PATH.
    "pwndbg"
    "pwndbg-lldb"
    "stm32cubeprogrammer"
    "tms320c28x-binja"
    "uniflash"
    # keep-sorted end
  ];
}
