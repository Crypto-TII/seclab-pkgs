#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# Bumps the package version pins that `nix flake update` cannot see.
#
# nix/update.nix holds the policy and substitutes the at-delimited placeholders
# below. Never name one in a comment: it is a plain string replace, and the
# multi-line call list would break out of the comment.

usage() {
  cat <<'USAGE'
update-packages -- bump the package pins that `nix flake update` cannot see.

usage: update-packages [nix-update-arg...]

`nix flake update` only moves flake.lock. Versions pinned inside packages/ are
invisible to it. This rewrites those in place; review `git diff` afterwards.

Extra arguments are forwarded to nix-update. Useful ones:
  --build     build each package after bumping it
  --commit    commit each bump as its own commit
  --format    run nixfmt over the files it rewrites
USAGE
}

case "${1-}" in
  -h | --help)
    usage
    exit 0
    ;;
esac

root=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$root" ] || [ ! -e "$root/flake.nix" ]; then
  echo "update-packages: run this from inside the seclab-pkgs checkout" >&2
  exit 1
fi
cd "$root" || exit 1

extra=("$@")
updated=()
unchanged=()
failed=()

# nix-update is chatty on stderr even when it succeeds; replay the transcript
# only on failure.
run_update() {
  local attr=$1
  shift
  local out line
  printf '==> %s\n' "$attr" >&2
  if out=$(nix-update --flake "$@" "${extra[@]}" "$attr" 2>&1); then
    if line=$(printf '%s\n' "$out" | grep -m1 '^Update '); then
      # `Update <old> -> <new> in <file>`. nix-update prints this even when the
      # two versions are equal (dynamorio does it on every run), so compare
      # rather than trusting the line's presence.
      change=${line#Update }
      old=${change%% -> *}
      new=${change#* -> }
      new=${new%% in *}
      if [ "$old" = "$new" ]; then
        unchanged+=("$attr")
      else
        updated+=("$attr: $change")
      fi
    else
      unchanged+=("$attr")
    fi
  else
    failed+=("$attr")
    printf '%s\n' "$out" >&2
  fi
}

@autoCalls@

printf '\n---- summary -------------------------------------------------\n'

if [ ${#updated[@]} -gt 0 ]; then
  printf '\nbumped:\n'
  printf '  %s\n' "${updated[@]}"
fi
if [ ${#unchanged[@]} -gt 0 ]; then
  printf '\nalready current:\n'
  printf '  %s\n' "${unchanged[@]}"
fi
if [ ${#failed[@]} -gt 0 ]; then
  printf '\nFAILED (transcript above):\n'
  printf '  %s\n' "${failed[@]}"
fi

cat <<'MANUAL'

manual -- vendor download portals, no feed to poll:
@manualBlock@
held -- temporary overrides, deliberately not bumped:
@pinnedBlock@
MANUAL

if [ ${#updated[@]} -gt 0 ]; then
  printf '\nReview the diff, then run: nix fmt && nix flake check\n'
fi

[ ${#failed[@]} -eq 0 ]
