#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# Stage the vendor artifacts in requiredFiles/ into the nix store so that
# `pkgs.requireFile` can resolve them, and print each one's hash.
#
# requireFile reads the *store*, never a path in the repo, so dropping a file in
# requiredFiles/ does nothing on its own -- this script is the bridge. See
# requiredFiles/README.md.
#
# Both hash formats are printed because the consumers disagree: Binary Ninja
# wants base32, stm32cubeprogrammer wants SRI.
#
# Requires: nix (nix-hash, nix-store, nix)

# Locate the checkout: PRJ_ROOT is set by the devshell, otherwise ask git.
root="${PRJ_ROOT:-}"
if [ -z "$root" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$root" ]; then
  echo "stage-required-files: cannot locate the checkout." >&2
  echo "  Run this from inside the repo, or set PRJ_ROOT." >&2
  exit 1
fi

dir="$root/requiredFiles"
if [ ! -d "$dir" ]; then
  echo "stage-required-files: no such directory: $dir" >&2
  exit 1
fi

shopt -s nullglob dotglob
staged=0
for f in "$dir"/*; do
  base="$(basename "$f")"
  # Bookkeeping, not artifacts.
  case "$base" in
  .gitkeep | README.md) continue ;;
  esac
  [ -f "$f" ] || continue

  # Idempotent: re-adding an already-present fixed-output path is a no-op.
  nix-store --add-fixed sha256 "$f" >/dev/null

  base32="$(nix-hash --type sha256 --flat --base32 "$f")"
  sri="$(nix hash file --type sha256 "$f" 2>/dev/null || nix hash path --flat --type sha256 "$f")"

  printf '%s\n' "$base"
  printf '  base32  %s\n' "$base32"
  printf '  sri     %s\n' "$sri"
  staged=$((staged + 1))
done

if [ "$staged" -eq 0 ]; then
  echo "stage-required-files: nothing to stage in $dir"
  echo "  Drop the vendor artifacts there first; see requiredFiles/README.md."
  exit 0
fi

echo
echo "staged $staged file(s) into the nix store"
