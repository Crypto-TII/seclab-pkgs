# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ callPackage }:
{
  # keep-sorted start
  dynamorio = callPackage ./dynamorio { };
  libtriton = callPackage ./libtriton { };
  # keep-sorted end
}
