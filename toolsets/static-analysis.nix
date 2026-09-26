# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ pkgs }:
with pkgs;
[
  # keep-sorted start
  cppcheck
  flawfinder
  semgrep
  # symcc needs compilable source: it instruments at build time, so it serves
  # lifted or rebuilt code, never a bare binary.
  symcc
  # keep-sorted end
]
