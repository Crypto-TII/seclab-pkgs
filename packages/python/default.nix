# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
# Python packages. Add entries as:
#   { python3Packages, ... }:
#   { my-tool = python3Packages.callPackage ./my-tool { }; }
{ python3Packages }:
{
  # keep-sorted start
  f28335-tools = python3Packages.callPackage ./f28335-tools { };
  svd2py = python3Packages.callPackage ./svd2py { };
  # keep-sorted end
}
