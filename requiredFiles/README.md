<!--
SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
SPDX-License-Identifier: Apache-2.0
-->

# requiredFiles

Drop-box for vendor artifacts that cannot be fetched automatically — proprietary
installers and licensed builds behind a login or a click-through agreement.

Everything in here is gitignored except this file and `.gitkeep`.

## Nix does not read this directory

That is the part worth internalising before using it. `pkgs.requireFile` resolves
a file **from the nix store**, not from a path in the repository: it builds a
fixed-output derivation that succeeds only if the artifact was already added with
`nix-store --add-fixed sha256`. It never looks here.

Gitignored files are also invisible to flake evaluation — Nix only sees
git-tracked files — so a path like `./requiredFiles/foo.zip` would not resolve
even if you tried.

So this directory is a **staging area for you**, and
[`stage-required-files`](../packages/misc/stage-required-files) is the bridge that
puts its contents where Nix can actually find them.

## Usage

1. Download the artifact and drop it in here, under the exact filename the
   package expects (see the table below).
2. Run the helper:

   ```console
   $ nix develop -c stage-required-files
   ```

   It adds each file to the nix store and prints its hash in both formats.

3. Put the hash where the package wants it. Some packages pin it themselves;
   Binary Ninja is consumer-supplied, because the licensed build differs per user:

   ```nix
   features.development.binaryninja = {
     enable = true;
     sha256 = "03ivd2iv9pa5xqw703aa46fzscb5shsxwj15vqwp6f6sj5kcpvaq";
   };
   ```

Re-running the helper is safe: adding an already-present fixed-output path is a
no-op.

## What consumes it

| Filename                                | Package                                   | Hash format                 |
| --------------------------------------- | ----------------------------------------- | --------------------------- |
| `binaryninja_linux_dev_ultimate.zip`    | Binary Ninja (`nixosModules.binaryninja`) | base32, set by the consumer |
| `SetupSTM32CubeProgrammer_linux_64.zip` | `stm32cubeprogrammer`                     | SRI, pinned in-package      |

The two formats are not interchangeable, which is why the helper prints both.

## If you skip this

Nothing breaks at evaluation time — `requireFile` is only forced when something
actually builds the package. You will see its message at build time instead,
naming the file it wants. That is the intended behaviour, not a failure of the
setup: hosts that never install these packages never need the artifacts.
