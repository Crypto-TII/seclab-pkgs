# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ python3Packages }:
{
  # keep-sorted start
  biosutilities = python3Packages.callPackage ./biosutilities { };
  f28335-tools = python3Packages.callPackage ./f28335-tools { };
  psptool = python3Packages.callPackage ./psptool { };
  svd2py = python3Packages.callPackage ./svd2py { };
  # keep-sorted end
}
