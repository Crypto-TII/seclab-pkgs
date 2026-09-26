# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# No gcc or binutils: mkShell's own stdenv already provides the cc-wrapper, and
# listing gcc here shadows it.
{ pkgs }:
with pkgs;
[
  # keep-sorted start
  bat
  cmake
  fd
  file
  git
  gnumake
  graphviz
  hexyl
  imhex
  jq
  kaitai-struct-compiler
  nasm
  ninja
  parallel
  patchelf
  pkg-config
  rehex
  ripgrep
  wireshark-cli
  # keep-sorted end
]
