# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{ pkgs }:
{
  # Both conditions fail late and cryptically otherwise: a missing attribute at
  # access time, and an unfree throw from a transitive dependency.
  requireSeclabPkgs =
    value:
    assert pkgs.lib.assertMsg (pkgs ? ghidra-re) ''
      This toolset needs seclab-pkgs' own packages, which reach `pkgs` through
      the overlay:

        pkgs = import nixpkgs {
          inherit system;
          overlays = [ seclab-pkgs.overlays.default ];
        };

      Without it you get `attribute 'ghidra-re' missing`.
    '';
    assert pkgs.lib.assertMsg (pkgs.config.allowUnfree or false) ''
      This toolset needs `config.allowUnfree = true`. ghidra-re and binwalk both
      reach dumpifs through ghidraninja-ghidra-scripts, so they fail with
      `Refusing to evaluate package 'dumpifs-...'` otherwise.
    '';
    value;

  # `targets` maps a qemu-user arch name to a pkgsCross set.
  mkCross =
    name: targets:
    let
      inherit (pkgs) lib;
      # A set targeting the host itself would put a bare `gcc` on PATH.
      foreign = lib.filterAttrs (
        _: cross: cross.stdenv.hostPlatform.config != pkgs.stdenv.hostPlatform.config
      ) targets;
    in
    [
      (pkgs.runCommand "seclab-${name}" { } (
        ''
          mkdir -p $out/bin
        ''
        + lib.concatStrings (
          lib.mapAttrsToList (
            arch: cross:
            let
              inherit (cross.stdenv) cc;
              sysroot = "$out/share/sysroots/${arch}";
            in
            # bin/ only: the wrappers' setup hooks would retarget mkShell's stdenv.
            # C++ needs libstdc++ beside glibc, and LD_LIBRARY_PATH: our ld.so skips /lib.
            ''
              ln -s -t $out/bin ${cc}/bin/*
              mkdir -p ${sysroot}/lib
              ln -s -t ${sysroot}/lib ${cross.glibc}/lib/* ${cc.cc.lib}/${cross.stdenv.hostPlatform.config}/lib/*
              ln -s lib ${sysroot}/lib64
              cat > $out/bin/qemu-${arch}-sysroot <<EOF
              #!${pkgs.runtimeShell}
              exec ${pkgs.qemu}/bin/qemu-${arch} -L ${sysroot} -E LD_LIBRARY_PATH=/lib "\$@"
              EOF
              chmod +x $out/bin/qemu-${arch}-sysroot
            ''
          ) foreign
        )
      ))
    ];
}
