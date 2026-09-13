# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# pwndbg flake resolves them from uv.lock, so this re-exports
# rather than repackages.
{ pwndbg }:

final: _prev:
let
  # The system lookup stays inside the values. Making the attribute *names*
  # depend on `final`.`
  forSystem = pwndbg.packages.${final.stdenv.hostPlatform.system};
in
{
  inherit (forSystem) pwndbg pwndbg-lldb;
}
