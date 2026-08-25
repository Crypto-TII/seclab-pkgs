#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
#
# FreeToken launcher, executed *inside* the FHS sandbox built by
# packages/misc/freetoken/default.nix.
#
# The sandbox supplies the parts Nix can supply (CUDA 13 toolkit, Python 3.12,
# clang/gcc, ninja, uv); this script supplies the parts it cannot — the four
# unpackaged CUDA kernel wheels — by resolving them into a persistent uv venv
# on first run, exactly as upstream's install.sh does.
#
# @version@ / @pythonVersion@ are substituted by the Nix derivation.

set -euo pipefail

FREETOKEN_HOME="${FREETOKEN_HOME:-$HOME/.freetoken}"
py_version="${FREETOKEN_PY_VERSION:-@pythonVersion@}"
venv="$FREETOKEN_HOME/venv"
spec="freetoken[accel]==@version@"

# The stamp records everything that would invalidate the venv. Bumping `version`
# in default.nix therefore re-resolves on the next run; there is no separate
# update command to remember.
stamp="$venv/.freetoken-nix-stamp"
want="$spec|python$py_version"

if [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$want" ]; then
  if [ -e "$venv" ]; then
    echo "==> FreeToken: venv at $venv is stale, rebuilding for $spec" >&2
  else
    echo "==> FreeToken: bootstrapping $spec into $venv" >&2
  fi
  echo "    This downloads several GB from PyPI and the cu130 wheel indexes;" >&2
  echo "    it only happens on the first run after a version change." >&2

  rm -f "$stamp"
  uv venv --python "$py_version" "$venv"
  uv pip install --python "$venv/bin/python" "$spec"
  printf '%s' "$want" >"$stamp"
  echo "==> FreeToken: bootstrap complete" >&2
fi

exec "$venv/bin/ft" "$@"
