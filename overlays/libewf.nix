# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# nixpkgs builds ewfmount without fuse: configure looks for a pkg-config `fuse`
# and does not detect fuse3, so the binary links neither and mounting an E01
# image fails at runtime. Everything else in libewf (ewfinfo, ewfexport,
# ewfacquire, ewfverify) works without it. Drop once nixpkgs builds ewfmount
# against fuse3.
final: prev: {
  libewf = prev.libewf.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ final.fuse ];
  });
}
