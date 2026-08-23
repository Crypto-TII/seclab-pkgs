# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# nixpkgs ships an incoherent angr suite: angr 9.2.193 pins archinfo/cle/pyvex
# to ==9.2.193 but they sit at 9.2.154, and angr's expression predates its Rust
# extension so it fails with "angr requires setuptools-rust to build".
#
# Bumping forward rather than back: 9.2.154 calls `self.clex.filename = ...`,
# which pycparser 3.00 rejects. Drop this file once nixpkgs ships a buildable
# angr.
final: prev:

let
  angrVersion = "9.2.193";

  pythonOverrides = pyfinal: pyprev: {
    # angr monkey-patches pycparser's 2.x lexer API; 3.00 rewrote it and the
    # patch dies at import with "property 'filename' ... has no setter".
    pycparser = pyprev.pycparser.overridePythonAttrs (
      finalAttrs: _prev: {
        version = "2.22";
        src = pyfinal.fetchPypi {
          pname = "pycparser";
          inherit (finalAttrs) version;
          hash = "sha256-SRyL6cBA9TkPW/RKWwd1K9B/Vu35kjgbBccBQ57sEPY=";
        };
      }
    );

    # cle 9.2.193 gained UEFI and Xbox loader backends; neither dep is packaged.
    uefi-firmware = pyfinal.buildPythonPackage (finalAttrs: {
      pname = "uefi_firmware";
      version = "1.16";
      pyproject = true;
      src = pyfinal.fetchPypi {
        inherit (finalAttrs) pname version;
        hash = "sha256-Fia5kwsQBvnsELde+In/wXxjLgtDpKugehCQ2QIxM+o=";
      };
      build-system = with pyfinal; [
        setuptools
        setuptools-scm
      ];
      env.SETUPTOOLS_SCM_PRETEND_VERSION = finalAttrs.version;
      pythonRemoveDeps = [ "future" ]; # py2 shim, unused on py3
      doCheck = false;
      pythonImportsCheck = [ "uefi_firmware" ];
      meta.description = "Parser for UEFI firmware volumes and BIOS images";
    });

    # cle's PE backend imports pyxdia unconditionally. Its sdist downloads a
    # prebuilt binary during setup.py, which the sandbox blocks -- use the wheel,
    # which already bundles it.
    pyxdia =
      let
        version = "0.1.1";
        wheels = {
          x86_64-linux = {
            file = "pyxdia-${version}-py3-none-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
            hash = "sha256-890kZ4wY1uoTdyyKFY7epVAasXz3R+QFFjCle/BIhP4=";
          };
          aarch64-linux = {
            file = "pyxdia-${version}-py3-none-manylinux_2_28_aarch64.whl";
            hash = "sha256-xTqJNj/w6hJWgdGxp3xxgjWZkuOtvtzCRLo7PBBVJCY=";
          };
          aarch64-darwin = {
            file = "pyxdia-${version}-py3-none-macosx_14_0_arm64.whl";
            hash = "sha256-kIo7xfqeRMOpl+mk+KmxUR7AmVeYspLzB3aNXoBcbHQ=";
          };
        };
        wheel =
          wheels.${final.stdenv.hostPlatform.system}
            or (throw "pyxdia: no prebuilt wheel for ${final.stdenv.hostPlatform.system}");
      in
      pyfinal.buildPythonPackage {
        pname = "pyxdia";
        inherit version;
        format = "wheel";
        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/py3/p/pyxdia/${wheel.file}";
          inherit (wheel) hash;
        };
        nativeBuildInputs = final.lib.optional final.stdenv.hostPlatform.isLinux final.autoPatchelfHook;
        buildInputs = final.lib.optional final.stdenv.hostPlatform.isLinux final.stdenv.cc.cc.lib;
        pythonImportsCheck = [ "pyxdia" ];
        meta.description = "Extract program information from PDB files (prebuilt wheel)";
      };

    archinfo = pyprev.archinfo.overridePythonAttrs (old: {
      version = angrVersion;
      src = old.src.override {
        tag = "v${angrVersion}";
        hash = "sha256-n7tbm+BHeCtKwsqcj56LB4YyQZRAp6Ehj7m91QFQrFM=";
      };
    });

    cle = pyprev.cle.overridePythonAttrs (old: {
      version = angrVersion;
      src = old.src.override {
        tag = "v${angrVersion}";
        hash = "sha256-YCmRNmUFtC5vl/zP0fyT63ODkz3Wo1ChwSY29hx7gwY=";
      };
      dependencies =
        (old.dependencies or [ ])
        ++ (with pyfinal; [
          arpy
          minidump
          pyxbe
          pyxdia
          uefi-firmware
        ]);
      # cle pins arpy==1.1.1; nixpkgs has 2.3.0, and arpy only backs the
      # ar-archive loader, not the ELF/Mach-O path.
      pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "arpy" ];
      # nixpkgs pins the test-data repo to 9.2.154, which predates this fixture.
      disabledTests = (old.disabledTests or [ ]) ++ [ "test_aarch64_macho_nop_stubs" ];
    });

    # 9.2.193 moved pyvex from a hand-rolled Makefile to scikit-build-core, so
    # nixpkgs' preBuild/setupPyBuildFlags no longer apply.
    pyvex = pyprev.pyvex.overridePythonAttrs (old: {
      version = angrVersion;
      src = old.src.override {
        version = angrVersion;
        hash = "sha256-8Je/mqxzzH6dH6FIA3WxEwC/qfa3dAqVPToDbqG3qUQ=";
      };
      build-system = with pyfinal; [
        scikit-build-core
        cffi
      ];
      nativeBuildInputs = [
        final.cmake
        final.ninja
        pyfinal.cffi
      ];
      dontUseCmakeConfigure = true; # scikit-build-core drives cmake itself
      # Upstream's CMakeLists misses a dependency edge between the generated
      # headers and the vex objects that include them, so a parallel build
      # compiles against half-written headers.
      env.CMAKE_BUILD_PARALLEL_LEVEL = "1";
      enableParallelBuilding = false;
      preBuild = "";
      setupPyBuildFlags = [ ];
    });

    angr = pyprev.angr.overridePythonAttrs (old: {
      # setup.py imports setuptools_rust and builds angr.rustylib.
      cargoDeps = final.rustPlatform.importCargoLock {
        lockFile = "${old.src}/Cargo.lock";
        outputHashes = {
          "icicle-cpu-0.1.0" = "sha256-8xmD2gG101+Uc0rAK78JoL86j++v3k9XcSijsMl95SU=";
        };
      };
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
        final.rustPlatform.cargoSetupHook
        final.cargo
        final.rustc
      ];
      build-system = (old.build-system or [ ]) ++ [
        pyfinal.setuptools-rust
        pyfinal.pyvex # setup.py reads its headers
      ];
      # nixpkgs' list is stale for 9.2.193: ailment merged into angr, several
      # deps dropped, lmdb/msgspec/pypcode/typing-extensions added.
      dependencies = with pyfinal; [
        archinfo
        cachetools
        capstone
        cffi
        claripy
        cle
        cppheaderparser
        cxxheaderparser
        gitpython
        lmdb
        msgspec
        mulpyplexer
        networkx
        protobuf
        psutil
        pycparser
        pydemumble
        pyformlang
        pypcode
        pyvex
        rich
        sortedcontainers
        sympy
        typing-extensions
        unique-log-filter
      ];
      # angr pins capstone==5.0.3; nixpkgs has 5.0.9.
      pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "capstone" ];
    });
  };
in
{
  python313 = prev.python313.override (old: {
    packageOverrides = final.lib.composeExtensions (old.packageOverrides or (_: _: { })
    ) pythonOverrides;
  });

  python313Packages = final.python313.pkgs;
}
