# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
#
# Upstream's Makefile builds out-of-tree, does not detect a non-Windows OS
# (hence OS=linux), and takes VERSION from `git describe`, absent in the sandbox.
{
  lib,
  stdenv,
  fetchFromGitHub,
  openspin,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "proploader";
  version = "1.0-37-unstable-2023-06-14";

  src = fetchFromGitHub {
    owner = "parallaxinc";
    repo = "PropLoader";
    rev = "a1b4cd87cedfb1141d9be888335bca130b486425";
    hash = "sha256-IkkgM0qy7PDbIQwI23R6QzXPrx+awVIqunkBVq5iIEE=";
  };

  nativeBuildInputs = [ openspin ];

  strictDeps = true;

  # The dir-creation rules (%/created) race under parallel make.
  enableParallelBuilding = false;

  makeFlags = [
    "OS=linux"
    "VERSION=${finalAttrs.version}"
  ];

  # Upstream's `install` target copies to ~/bin; the artifact lands out-of-tree.
  installPhase = ''
    runHook preInstall
    install -Dm755 ../proploader-linux-build/bin/proploader "$out/bin/proploader"
    runHook postInstall
  '';

  meta = {
    description = "Command-line loader for the Parallax Propeller (e.g. flashing the JTAGulator)";
    homepage = "https://github.com/parallaxinc/PropLoader";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "proploader";
  };
})
