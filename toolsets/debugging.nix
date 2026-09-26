# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ pkgs }:
let
  seclab = import ./lib.nix { inherit pkgs; };
in
seclab.requireSeclabPkgs (
  with pkgs;
  [
    # keep-sorted start
    bpftrace
    frida-tools
    gdb
    gef
    lldb
    ltrace
    pwndbg
    pwndbg-lldb
    qemu
    rr
    strace
    valgrind
    # keep-sorted end
  ]
)
