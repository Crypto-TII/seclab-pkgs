# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# One pin for the two packages built out of this tree -- bindiff, whose CMake
# build needs the whole thing, and ghidra-binexport, which builds its java/
# subtree. The exporter writes what the differ reads, so they must not drift.
{ fetchFromGitHub }:

fetchFromGitHub {
  owner = "google";
  repo = "binexport";
  rev = "fdcfad4c55e9b52bcc5f005171c0cf91c30c2cc2";
  hash = "sha256-YB9cudw+0xLvdsS8fbfoSaKIsZdDFeZIQgeJocQhj2w=";
}
