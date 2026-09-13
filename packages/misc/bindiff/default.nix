# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 Brian McGillion
#
# Built from main, not the v8 tag: that release is from 2023 and upstream has
# been committing to main since. The GUI is the exception -- java/ui resolves
# `:y:` and `:ysvg:` from a flatDir repository, the commercial yFiles layout
# library, which upstream cannot ship in source form. Its jar therefore still
# comes from the last release .deb.
{
  lib,
  stdenv,
  binexportSource,
  fetchFromGitHub,
  fetchurl,
  fetchzip,
  cmake,
  ninja,
  dpkg,
  makeWrapper,
  jdk21,
}:

let
  # BinExportDeps.cmake FetchContents these at exact revisions and offers no
  # find_package fallback, so they are supplied as sources rather than taken
  # from nixpkgs; FETCHCONTENT_SOURCE_DIR_* below points CMake at them.
  absl = fetchzip {
    url = "https://github.com/abseil/abseil-cpp/archive/ce1a8f1ec1793e5cb9d7fffa281efdfea5dd8035.zip";
    hash = "sha256-9eOXEq0zS1aaleRCvq53lq/BMM1K/cKs4KCaDaVMtvg=";
  };
  protobuf = fetchzip {
    url = "https://github.com/protocolbuffers/protobuf/releases/download/v35.1/protobuf-35.1.tar.gz";
    hash = "sha256-nif9xjd+3ASR2pvvSXkzTEWoKi2oKLzV9gMQ3EevBVk=";
  };
  sqlite = fetchzip {
    url = "https://sqlite.org/2026/sqlite-amalgamation-3530300.zip";
    hash = "sha256-QgNam6cJkD3hVe8B/EZBapbneu6N23ehrgzy35egCcw=";
  };

  # v8 is the newest release, and the only redistributable build of the UI.
  releaseDeb = fetchurl {
    url = "https://github.com/google/bindiff/releases/download/v8/bindiff_8_amd64.deb";
    hash = "sha256-ghmQ45dKnfZzN5Q3DkhUhqwna6XXd6BrTr5XXwkvTdo=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "bindiff";
  version = "8-unstable-2026-09-09";

  src = fetchFromGitHub {
    owner = "google";
    repo = "bindiff";
    rev = "4b643a1b234063c7a1590a832e7817f04cd85a95";
    hash = "sha256-juE6GizgdANcK45XqHvvPaaf+d8gREKIERIb8585Xyk=";
  };

  nativeBuildInputs = [
    cmake
    dpkg
    makeWrapper
    ninja
  ];

  cmakeFlags = [
    # CMakeLists expects the tree beside it and pulls its targets in with
    # add_subdirectory.
    (lib.cmakeFeature "BINDIFF_BINEXPORT_DIR" "${binexportSource}")
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_ABSL" "${absl}")
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_PROTOBUF" "${protobuf}")
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_SQLITE" "${sqlite}")
    # Both plugins need an SDK fetched from git at configure time.
    (lib.cmakeBool "BINEXPORT_ENABLE_IDAPRO" false)
    (lib.cmakeBool "BINEXPORT_ENABLE_BINARYNINJA" false)
    (lib.cmakeBool "BUILD_TESTING" false)
    # Turns a missed FetchContent into a configure error rather than a silent
    # download attempt that the sandbox fails later and less legibly.
    (lib.cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
  ];

  # The only revision hook upstream's CMakeLists reads; without it the banner
  # says "@internal", which tells a main-tracking build's user nothing.
  env.KOKORO_PIPER_CHANGELIST = finalAttrs.src.rev;

  # binexport is added EXCLUDE_FROM_ALL, so its tools need naming.
  ninjaFlags = [
    "bindiff"
    "binexport2dump"
    "bindiff_config_setup"
  ];

  # Upstream's only install() rule puts bindiff back in the build tree, for its
  # own packaging scripts to pick up; there is no prefix install to run.
  dontUseCmakeInstall = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bindiff "$out/bin/bindiff"
    install -Dm755 _deps/binexport-build/tools/binexport2dump "$out/bin/binexport2dump"
    install -Dm755 tools/bindiff_config_setup "$out/bin/bindiff-config-setup"

    dpkg-deb -x ${releaseDeb} deb
    install -Dm644 deb/opt/bindiff/bin/bindiff.jar "$out/share/bindiff/bindiff.jar"
    install -Dm644 deb/usr/share/icons/hicolor/256x256/apps/com-google-security-zynamics-bindiff.png \
      "$out/share/icons/hicolor/256x256/apps/com-google-security-zynamics-bindiff.png"
    install -Dm644 deb/usr/share/applications/com-google-security-zynamics-bindiff-Launcher.desktop \
      "$out/share/applications/com-google-security-zynamics-bindiff-Launcher.desktop"
    substituteInPlace "$out/share/applications/com-google-security-zynamics-bindiff-Launcher.desktop" \
      --replace-fail /opt/bindiff/bin/bindiff_ui "$out/bin/bindiff-ui"

    # Straight to the jar: the launcher inside the differ locates it through
    # `directory` and `ui.java_binary`, which the .deb's postinst writes into
    # /etc/opt and no store path can supply.
    makeWrapper "${lib.getExe jdk21}" "$out/bin/bindiff-ui" \
      --add-flags "-jar $out/share/bindiff/bindiff.jar"

    runHook postInstall
  '';

  meta = {
    description = "Comparison tool for binaries, to find differences and similarities in disassembled code";
    longDescription = ''
      The differ, `binexport2dump` and the config tool are built from upstream's
      main branch. `bindiff-ui` runs the prebuilt jar from the v8 release,
      because the UI links the commercial yFiles library and cannot be built
      from source -- so the GUI is three years older than the differ it drives.

      The IDA Pro and Binary Ninja exporters are not built -- both need vendor
      SDKs fetched at configure time. For Ghidra, `ghidra-binexport` builds the
      exporter from the same BinExport checkout, and `ghidra-re` carries it.
    '';
    homepage = "https://github.com/google/bindiff";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode # the UI jar
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "bindiff";
  };
})
