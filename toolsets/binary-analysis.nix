# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ pkgs }:
let
  inherit (pkgs) lib;
  seclab = import ./lib.nix { inherit pkgs; };

  # capa looks for rules/ and sigs/ beside its package, which nixpkgs does not
  # install; without them it exits 10 on every sample. The source carries both.
  capa = pkgs.python3Packages.toPythonApplication (
    pkgs.python3Packages.capa.overridePythonAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        ln -s ${old.src}/rules ${old.src}/sigs $out/${pkgs.python3.sitePackages}/
      '';
    })
  );

  # nixpkgs builds afl-qemu-trace for the host arch only. ppc64 and ppc64le
  # are absent: qemuafl's target/ppc does not compile with current gcc.
  aflQemuTargets = [
    "aarch64"
    "arm"
    "i386"
    "mips"
    "mips64"
    "mips64el"
    "mipsel"
    "ppc"
    "riscv64"
    "x86_64"
  ];
  aflQemu = pkgs.aflplusplus.qemu.overrideAttrs (old: {
    configureFlags = [
      "--target-list=${lib.concatMapStringsSep "," (t: "${t}-linux-user") aflQemuTargets}"
    ]
    ++ lib.filter (f: !lib.hasPrefix "--target-list=" f) old.configureFlags;
  });
  # afl-fuzz, afl-showmap and afl-tmin all find afl-qemu-trace through AFL_PATH.
  afl-qemu-arch = pkgs.runCommand "afl-qemu-arch" { } ''
    ${lib.concatMapStrings (t: ''
      mkdir -p $out/share/afl-qemu/${t}
      ln -s ${aflQemu}/bin/qemu-${t} $out/share/afl-qemu/${t}/afl-qemu-trace
    '') aflQemuTargets}
    mkdir -p $out/bin
    cat > $out/bin/afl-qemu-arch <<EOF
    #!${pkgs.runtimeShell}
    arch=\''${1:?usage: afl-qemu-arch <arch> <afl command...>}
    [ -d $out/share/afl-qemu/\$arch ] || { echo "no afl-qemu-trace for \$arch; have: ${toString aflQemuTargets}" >&2; exit 1; }
    shift
    AFL_PATH=$out/share/afl-qemu/\$arch exec "\$@"
    EOF
    chmod +x $out/bin/afl-qemu-arch
  '';
in
seclab.requireSeclabPkgs (
  with pkgs;
  [
    # keep-sorted start
    bloaty
    capa
    capstone
    checksec
    # Minimal, not full: the full build drags ghc, ocaml, mono and four JDKs.
    diffoscopeMinimal
    dwarfdump
    elfutils
    flare-floss
    honggfuzz
    keystone
    # libtriton, not triton: the module it installs is named triton, which
    # would collide with python3Packages.triton.
    libtriton
    lief
    one_gadget
    osslsigncode
    pahole
    pax-utils
    pev
    radamsa
    ropgadget
    unicorn
    upx
    yara-x
    # keep-sorted end
  ]
  ++ lib.optionals stdenv.hostPlatform.isx86_64 [
    afl-qemu-arch
    aflplusplus
    bindiff
    # meta.platforms is x86_64-linux; upstream treats aarch64 as a cross target.
    dynamorio
  ]
)
