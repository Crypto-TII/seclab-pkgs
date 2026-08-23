# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
"""f28335-tools command line interface."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

from . import __version__
from .dump import DEFAULT_CCXML, dump
from .reconstruct import reconstruct
from .stitch import stitch


def _env_flag(name: str, default: bool = True) -> bool:
    """Honour the RECONSTRUCT=0 / STITCH=0 switches the shell scripts used."""
    return os.environ.get(name, "1" if default else "0") != "0"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="f28335-tools",
        description="Dump, reconstruct and stitch TMS320F28335 memory.",
    )
    ap.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    sub = ap.add_subparsers(dest="command", required=True)

    # Defaults come from the environment variables the shell scripts honoured,
    # so existing notes and habits keep working.
    p_dump = sub.add_parser("dump", help="two-pass capture via dslite + XDS200")
    p_dump.add_argument(
        "--ccxml",
        type=Path,
        default=Path(os.environ.get("CCXML", DEFAULT_CCXML)),
        help="target configuration .ccxml (default: bundled XDS200+F28335)",
    )
    p_dump.add_argument(
        "--outdir",
        type=Path,
        default=Path(os.environ["OUTDIR"]) if os.environ.get("OUTDIR") else None,
        help="output parent dir (default: ./dumps/<timestamp>)",
    )
    p_dump.add_argument(
        "--reset-op",
        type=int,
        default=int(os.environ.get("RESET_OP", "0")),
        help="reset-operation INDEX for 'dslite flash --reset' (default: 0, CPU Reset)",
    )
    p_dump.add_argument(
        "--no-reconstruct",
        dest="reconstruct",
        action="store_false",
        default=_env_flag("RECONSTRUCT"),
        help="skip the reconstruct stage",
    )
    p_dump.add_argument(
        "--no-stitch",
        dest="stitch",
        action="store_false",
        default=_env_flag("STITCH"),
        help="skip the stitch stage",
    )

    p_rec = sub.add_parser(
        "reconstruct", help="rebuild a dump into a COFF + disassembly"
    )
    p_rec.add_argument("dump_dir", type=Path, help="dir holding the *.bin files")

    p_st = sub.add_parser("stitch", help="splice regions into one 8 MiB chip image")
    p_st.add_argument("dump_dir", type=Path, help="dir holding the *.bin files")

    args = ap.parse_args(argv)

    if args.command == "dump":
        dump(
            outdir=args.outdir,
            ccxml=args.ccxml,
            reset_op=args.reset_op,
            reconstruct=args.reconstruct,
            stitch=args.stitch,
        )
    elif args.command == "reconstruct":
        reconstruct(args.dump_dir.resolve())
    elif args.command == "stitch":
        stitch(args.dump_dir.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
