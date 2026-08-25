# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
# FreeToken — edge-native MoE serving engine, wrapped in an FHS sandbox.
#
# Why FHS rather than a normal Nix package: FreeToken's pyproject.toml pins
# torch>=2.11,<2.12 (cu130) plus four CUDA kernel wheels that nixpkgs does not
# carry (apache-tvm-ffi, flashlib, sglang-kernel, flashinfer-python), served
# from dedicated wheel indexes.
#
# Provides two commands:
#   ft        — the CLI; bootstraps the venv on first run, then execs it
#   ft-shell  — an interactive shell in the same sandbox, for debugging a failed
#               bootstrap or working on a FreeToken source checkout
#
# Consumed by nixosModules.freetoken (modules/freetoken/nixos.nix).
{
  lib,
  buildFHSEnv,
  replaceVars,
  symlinkJoin,
  bashInteractive,
  cacert,
  clang,
  coreutils,
  cudaPackages_13,
  curl,
  gcc13,
  git,
  ninja,
  numactl,
  openssl,
  python312,
  runCommand,
  stdenv,
  uv,
  which,
  zlib,
}:

let
  # Upstream python/freetoken/version.py. Bumping this is what re-resolves the
  # user's venv on next run (see the stamp logic in ft-launcher.sh).
  version = "0.1.2";

  # install.sh's own default, and the newest cp-tag these wheels publish. The
  # pinned nixpkgs python3 is 3.14, which no freetoken dependency builds for.
  python = python312;
  pythonVersion = lib.versions.majorMinor python.version;

  cuda = cudaPackages_13;

  gcc13-aliases = runCommand "gcc13-versioned-aliases" { } ''
    mkdir -p $out/bin
    ln -s ${lib.getExe' gcc13 "g++"} $out/bin/g++-13
    ln -s ${lib.getExe' gcc13 "gcc"} $out/bin/gcc-13
  '';

  targetPkgs = _: [
    # Python side: uv drives the venv, python is the interpreter it targets.
    python
    uv

    # CUDA 13. cudatoolkit is the merged layout (bin/nvcc + include + lib64)
    # that torch's CUDA_HOME detection and setup.py:_cuda_runtime_paths expect;
    # the individual libs are what the prebuilt wheels dlopen at runtime.
    cuda.cudatoolkit
    cuda.cuda_cudart
    cuda.cuda_nvrtc
    cuda.libcublas
    cuda.libnvjitlink

    # JIT host toolchain. kernel/gguf.py:_host_compiler prefers clang++ and
    # falls back to g++-13..15 — the default g++ is too new for torch's headers.
    clang
    gcc13
    gcc13-aliases
    ninja

    # attention/fa.py diagnoses a missing libnuma by name.
    numactl

    # Generic manylinux wheel needs + bootstrap tooling.
    bashInteractive
    cacert
    coreutils
    curl
    git
    openssl
    stdenv.cc.cc.lib
    which
    zlib
  ];

  # Sourced inside the sandbox before runScript.
  #
  # CUDA_HOME is set explicitly rather than left to torch's `which nvcc`
  # heuristic: that yields /usr, whose lib64 the FHS root does not necessarily
  # materialise, and setup.py hard-errors when CUDA_HOME is unusable. The store
  # path is readable because buildFHSEnv binds /nix/store into the sandbox.
  #
  # CC/CXX are deliberately left unset — kernel/gguf.py sets them itself from
  # whichever host compiler it picked, and forcing them here would fight it.
  # FREETOKEN_ALLOW_CUDA_MISMATCH is likewise left unset: if the toolkit ever
  # drifts off torch's CUDA major we want the loud _toolchain.py error rather
  # than silently mislinked kernels.
  profile = ''
    export CUDA_HOME=${cuda.cudatoolkit}
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
  '';

  launcher = replaceVars ./ft-launcher.sh {
    inherit version pythonVersion;
  };

  ft = buildFHSEnv {
    name = "ft";
    inherit targetPkgs profile;
    runScript = "${bashInteractive}/bin/bash ${launcher}";
  };

  ft-shell = buildFHSEnv {
    name = "ft-shell";
    inherit targetPkgs profile;
    runScript = "bash";
  };
in
symlinkJoin {
  name = "freetoken-${version}";
  inherit version;

  paths = [
    ft
    ft-shell
  ];

  meta = {
    description = "Edge-native MoE serving engine for frontier open-weight models (FHS-wrapped)";
    longDescription = ''
      FreeToken runs frontier-scale open-weight Mixture-of-Experts models on
      consumer NVIDIA hardware with bandwidth-adaptive CPU-GPU co-execution, and
      serves them over OpenAI- and Anthropic-compatible APIs.

      This package is an FHS sandbox, not a build of FreeToken itself: `ft`
      resolves the runtime into a uv venv under $FREETOKEN_HOME (default
      ~/.freetoken) on first run, which requires network access.
    '';
    homepage = "https://github.com/FlashML-org/FreeToken";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ft";
  };
}
