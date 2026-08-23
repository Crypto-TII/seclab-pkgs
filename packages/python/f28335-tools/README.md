<!--
SPDX-License-Identifier: MIT
SPDX-FileCopyrightText: 2025 Brian McGillion
-->

# f28335-tools

Dump, reconstruct and stitch the memory of a **TMS320F28335** over an XDS200 USB
JTAG probe.

Three stages, one binary:

| Subcommand    | What it does                                                                                                                          |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `dump`        | Two-pass capture of Flash, RAM, Boot ROM, OTP and peripheral frames via TI UniFlash's `dslite`                                        |
| `reconstruct` | Rebuilds a dump into a linkable COFF (`cl2000`) plus disassembly (`dis2000`), verifies byte fidelity, and writes a code/data manifest |
| `stitch`      | Splices the region `.bin` files into one flat 8 MiB chip image for Binary Ninja                                                       |

`dump` runs all three by default, so the common case is a single command.

## Requirements

- An **XDS200** probe attached to an F28335, and no other `DSLite` process
  holding it (`dump` refuses to start if one is running).
- `dslite` (from `uniflash`) and `cl2000` / `dis2000` (from `c2000-cgt`). The Nix
  wrapper puts all three on `PATH`, so there is nothing to install by hand.

On NixOS this arrives with `features.development.uniflash.enable = true`, which
also installs the udev rules the probe needs.

## Quick start

```console
$ f28335-tools dump
```

Captures both passes, reconstructs the reset pass, and stitches a chip image —
writing everything under `./dumps/<timestamp>/`.

To work on a capture you already have:

```console
$ f28335-tools reconstruct dumps/20260823-101500/dump-reset
$ f28335-tools stitch      dumps/20260823-101500/dump-reset
```

## `dump`

```console
$ f28335-tools dump [--ccxml PATH] [--outdir DIR] [--reset-op N]
                    [--no-reconstruct] [--no-stitch]
```

Two passes, because they answer different questions:

- **`dump-halt/`** — halt only. What the chip looked like when you stopped it.
- **`dump-reset/`** — CPU reset, then read. This is the pass that gets
  reconstructed; the halt pass diverges from true chip state because the DSS halt
  perturbs some peripheral registers.

Each region is its own `dslite` invocation (connect, halt, read, disconnect), so
one failing region does not abort the run — it is counted and reported, and the
command exits non-zero at the end.

RAM in the reset pass reflects _shortly after_ reset, not a perfectly frozen
reset state: the device runs for a few hundred ms between reads. Flash, OTP and
Boot ROM are non-volatile and unaffected.

| Option             | Default                      | Notes                                             |
| ------------------ | ---------------------------- | ------------------------------------------------- |
| `--ccxml`          | bundled XDS200+F28335 config | `$CCXML` also honoured                            |
| `--outdir`         | `./dumps/<timestamp>`        | `$OUTDIR` also honoured                           |
| `--reset-op`       | `0` (CPU Reset)              | `$RESET_OP`. An **index**, not a name — see below |
| `--no-reconstruct` | run it                       | `RECONSTRUCT=0` also honoured                     |
| `--no-stitch`      | run it                       | `STITCH=0` also honoured                          |

`--reset-op` takes an index rather than a name because the `dslite` wrapper
re-splits space-containing arguments like `"CPU Reset"` into stray flash
operands. To enumerate the operations for your target:

```console
$ dslite flash --config=<ccxml> --list-resets
```

### Output

```
dumps/<timestamp>/
├── dump-halt/          <region>.bin + <region>.log per region
├── reset.log
└── dump-reset/         same, plus whatever reconstruct and stitch produce
```

`csm_pwl` is deliberately read **last**: reading it earlier can trip the CSM lock
for the rest of the run. If the device is CSM-locked, `flash` and `user_otp` will
fail while everything else still succeeds.

## `reconstruct`

```console
$ f28335-tools reconstruct <dump-dir>
```

Encodes each `<region>.bin` as assembly, links it with `cl2000`, disassembles
with `dis2000`, then checks the result and classifies it:

```
<dump-dir>/
├── reconstruct/    <section>.asm, build.cmd
├── link/           dumped.out, dumped.map
├── dis/            dumped.dis, dumped.analysis.json
└── log/            <timestamp>-reconstruct.log   (full transcript)
```

Two things worth knowing about the output:

- **`dumped.dis` is disassembled with `--data_as_text --all`.** A COFF rebuilt
  from `.word` data is entirely `STYP_DATA` — TI only marks `STYP_TEXT` for
  assembled instructions — and re-emitting decoded mnemonics would break byte
  fidelity. Code/data structure therefore lives in the JSON manifest, not in the
  `.dis`.
- **`dumped.analysis.json`** is the contract consumed by the Binary Ninja sidecar
  importer: function entries plus code/data ranges, in chip-word addresses.

Two checks run at the end, with deliberately different severity:

- **Byte fidelity is fatal.** If the derived COFF is not byte-identical to the
  raw dump, the command fails. Everything downstream — the disassembly, CRC
  tooling — is untrustworthy otherwise.
- **Classification is best effort.** A decode failure is reported and the run
  continues; a good reconstruction should not be sunk by the classifier.

`csm_pwl` is excluded from the linker layout: it sits inside `.flash` at chip
`0x33FFF8..0x33FFFF` and would be an overlap error. `stitch` includes it, because
there it writes the same bytes `flash.bin` already carries.

If your flash capture has been renamed per variant — `g103-flash.bin` and
friends — both `reconstruct` and `stitch` find it automatically. A plain
`flash.bin` wins if both are present; `flash_*.bin` sector splits are ignored.

## `stitch`

```console
$ f28335-tools stitch <dump-dir>
```

Writes `<dump-dir>/chip_image.bin`: 8 MiB, gaps filled with `0xFF` to match
erased flash, each region placed at **byte offset = chip word address × 2**
(Binary Ninja's C28x convention, `BN_byte = 2 * chip_word`).

Load it in Binary Ninja the way you load `flash.bin`, but at base address 0.
Cross-region xrefs — flash → SARAM ramfuncs, flash → M0 stubs, flash → Boot ROM —
then resolve inside a single view.

The sha256 of the image is printed, and the run fails if the final size is not
exactly 8 MiB.

## Development

```console
$ nix build .#f28335-tools     # the test suite runs as part of the build
$ nix develop -c pytest        # or run it directly
```

The region tables in `f28335_tools/regions.py` were transcribed mechanically from
the shell scripts this replaced, and are covered by tests — a wrong address is a
silently corrupt dump, not a crash. Note that `page` means different things in
`DUMP_REGIONS` (the C28x address-space tag for `dslite --range`) and
`LINK_REGIONS` (the TI linker `PAGE`); `m0_saram` is page 0 in one and page 1 in
the other.

`f28335_tools/asmcodec.py` must stay bit-exact: it feeds the linker whose COFF is
checked byte-for-byte against the raw dump, so any drift shows up as a
byte-fidelity failure.

The `c28x` instruction decoder comes from
[tms320c28x-re](https://github.com/brianmcgillion/tms320c28x-re) as a normal
dependency; it is imported lazily, so `stitch` and `dump` work even when it is
unavailable.
