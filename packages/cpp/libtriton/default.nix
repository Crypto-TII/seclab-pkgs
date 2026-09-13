# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# `libtriton`, not `triton`: the Python module installed here is named `triton`
# and would collide with python3Packages.triton (OpenAI's, a torch dependency).
# Consumers put $out/lib/python3.x/site-packages on PYTHONPATH themselves.
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  capstone,
  bitwuzla,
  boost,
  llvm,
  python3,
  z3,
  withBitwuzla ? true,
  withBoost ? true,
  withLLVM ? true,
  withPython ? true,
  withZ3 ? true,
}:

stdenv.mkDerivation (_finalAttrs: {
  pname = "libtriton";
  # Master pin: the last tag is v0.9 (2022), ~800 commits behind a tree that
  # predates the Bitwuzla and LLVM support enabled below.
  version = "0.9-unstable-2026-05-11";

  # Keeps LLVM, Z3 and Boost dev outputs out of the runtime closure; only the
  # CMake package config references them.
  outputs = [
    "out"
    "dev"
  ];

  src = fetchFromGitHub {
    owner = "JonathanSalwan";
    repo = "Triton";
    rev = "bc84cf745e99768e07d51dcd734eba35c59f1b3e";
    hash = "sha256-mj+WnlzUEmApBLe4LyWg/oZveokAEt8UpGDgJ6Tu4Ig=";
  };

  strictDeps = true;

  nativeBuildInputs = [
    cmake
    ninja
  ]
  # find_program(PYTHON_EXECUTABLE ...) passes NO_CMAKE_PATH, so it walks $PATH.
  ++ lib.optional withPython python3;

  buildInputs = [
    capstone
  ]
  ++ lib.optional withBitwuzla bitwuzla
  ++ lib.optional withLLVM llvm
  ++ lib.optional withPython python3
  ++ lib.optional withZ3 z3;

  # ABI-affecting: with TRITON_BOOST_INTERFACE set, tritonTypes.hpp types
  # uint80/128/256/512 as boost::multiprecision, so consumers must agree.
  propagatedBuildInputs = lib.optional withBoost boost;

  cmakeFlags = [
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
    (lib.cmakeBool "BITWUZLA_INTERFACE" withBitwuzla)
    (lib.cmakeBool "BOOST_INTERFACE" withBoost)
    (lib.cmakeBool "LLVM_INTERFACE" withLLVM)
    (lib.cmakeBool "PYTHON_BINDINGS" withPython)
    (lib.cmakeBool "Z3_INTERFACE" withZ3)

    # Would install triton.pyi to an absolute path outside $out, and the stub is
    # never generated anyway since python_autocomplete is not in ALL.
    (lib.cmakeBool "PYTHON_BINDINGS_AUTOCOMPLETE" false)
  ]
  ++ lib.optionals withPython [
    (lib.cmakeFeature "PYTHON_EXECUTABLE" python3.interpreter)
    # Relative, so it resolves against CMAKE_INSTALL_PREFIX.
    (lib.cmakeFeature "PYTHON_SITE_PACKAGES" python3.sitePackages)
    # Config.cmake.in interpolates both, but CMakeLists.txt never sets either
    # from what find_package(Python3) found. Unset, the installed config emits
    # `include_directories("")` and every find_package(triton) hard-errors.
    (lib.cmakeFeature "PYTHON_INCLUDE_DIRS" "${python3}/include/python${python3.pythonVersion}")
    (lib.cmakeFeature "PYTHON_LIB_DIR" "${python3}/lib")
  ]
  ++ lib.optionals withLLVM [
    # LLVMConfig.cmake sets this as a plain variable, but Triton tests $CACHE{},
    # which is empty -- it then appends -fuse-ld=lld, and llvm/bin has no ld.lld.
    (lib.cmakeBool "LLVM_LINK_LLVM_DYLIB" true)
  ];

  # The suite needs unicorn and lief, and test_examples.py runs every script
  # under src/examples/python. The installCheck below is the smoke test.
  doCheck = false;

  postInstall =
    lib.optionalString withBoost ''
      # find_package(Boost) is not REQUIRED: a miss silently falls back to the
      # vendored uintwide_t.h and changes the public integer typedefs.
      grep -q 'define TRITON_BOOST_INTERFACE' "$dev/include/triton/config.hpp" || {
        echo "BOOST_INTERFACE=ON but config.hpp disagrees: find_package(Boost) missed." >&2
        exit 1
      }
    ''
    + ''
      # Headers install to $dev, and the export set follows, but Config.cmake.in
      # interpolates CMAKE_INSTALL_PREFIX and so points at an empty $out/include.
      substituteInPlace "$out/lib/cmake/triton/tritonConfig.cmake" \
        --replace-fail "$out/include" "$dev/include"
    '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck

    # The C++ consumer path the output split can break.
    mkdir -p "$NIX_BUILD_TOP/consumer"
    cd "$NIX_BUILD_TOP/consumer"

    cat > main.cpp <<'EOF'
    #include <triton/context.hpp>
    int main() {
      triton::Context ctx;
      return 0;
    }
    EOF

    cat > CMakeLists.txt <<'EOF'
    cmake_minimum_required(VERSION 3.20)
    project(triton_consumer CXX)
    find_package(triton REQUIRED)
    add_executable(triton_consumer main.cpp)
    target_link_libraries(triton_consumer PRIVATE triton)
    set_property(TARGET triton_consumer PROPERTY CXX_STANDARD 17)
    EOF

    cmake -S . -B build -DCMAKE_PREFIX_PATH="$dev"
    cmake --build build
    ./build/triton_consumer
    echo "libtriton find_package consumer OK"

    cd "$NIX_BUILD_TOP"
  ''
  # The SOLVER members only exist when the backend was compiled in.
  + lib.optionalString withPython ''
    PYTHONPATH="$out/${python3.sitePackages}" ${python3.interpreter} -c '
    from triton import ARCH, SOLVER, TritonContext
    ctx = TritonContext(ARCH.X86_64)
    ${lib.optionalString withZ3 "ctx.setSolver(SOLVER.Z3)"}
    ${lib.optionalString withBitwuzla "ctx.setSolver(SOLVER.BITWUZLA)"}
    print("libtriton smoke test OK")
    '
  ''
  + ''
    runHook postInstallCheck
  '';

  meta = {
    description = "Dynamic binary analysis library: symbolic execution, taint analysis and SMT lifting";
    homepage = "https://github.com/JonathanSalwan/Triton";
    license = [
      lib.licenses.asl20
      lib.licenses.boost # vendored includes/triton/uintwide_t.h
      lib.licenses.mit # vendored includes/triton/py3c_compat.h
    ];
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
