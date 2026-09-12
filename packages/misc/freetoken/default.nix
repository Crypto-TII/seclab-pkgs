# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
# FHS rather than a normal package: pyproject.toml pins torch cu130 plus four
# CUDA kernel wheels nixpkgs does not carry, served from dedicated indexes.
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
  # Bumping this re-resolves the user's venv on next run (ft-launcher.sh).
  version = "0.1.2";

  # The pinned python3 is 3.14, which no freetoken dependency builds for.
  python = python312;
  pythonVersion = lib.versions.majorMinor python.version;

  cuda = cudaPackages_13;

  gcc13-aliases = runCommand "gcc13-versioned-aliases" { } ''
    mkdir -p $out/bin
    ln -s ${lib.getExe' gcc13 "g++"} $out/bin/g++-13
    ln -s ${lib.getExe' gcc13 "gcc"} $out/bin/gcc-13
  '';

  targetPkgs = _: [
    python
    uv

    # cudatoolkit is the merged layout torch's CUDA_HOME detection expects;
    # the individual libs are what the prebuilt wheels dlopen at runtime.
    cuda.cudatoolkit
    cuda.cuda_cudart
    cuda.cuda_nvrtc
    cuda.libcublas
    cuda.libnvjitlink

    # kernel/gguf.py falls back to g++-13..15; the default g++ is too new for
    # torch's headers.
    clang
    gcc13
    gcc13-aliases
    ninja

    # attention/fa.py diagnoses a missing libnuma by name.
    numactl

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

  # CUDA_HOME explicitly: torch's `which nvcc` heuristic yields /usr, whose
  # lib64 the FHS root may not materialise. CC/CXX stay unset so gguf.py picks.
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
