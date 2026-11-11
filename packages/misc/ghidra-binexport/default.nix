# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 Brian McGillion
#
# The half of BinExport that produces the .BinExport files bindiff consumes.
# Built from main against this Ghidra: upstream's last release is v12 (2023),
# and the prebuilt extension in the BinDiff .deb records a Ghidra version that
# 12.x refuses to load.
{
  lib,
  binexportSource,
  fetchFromGitHub,
  ghidra,
  ghidra-extensions,
  gradle,
  protobuf_31,
}:

let
  # Ghidra 12.1.2 ships protobuf-java 4.31.0 and its copy wins the extension's
  # classloader, while protoc stamps its own version into the generated code
  # and protobuf refuses a runtime older than that gencode. nixpkgs' protobuf_31
  # is 31.1, one patch too new, so it is pinned back to the matching release.
  protoc = protobuf_31.overrideAttrs (
    finalAttrs: _: {
      version = "31.0";
      src = fetchFromGitHub {
        owner = "protocolbuffers";
        repo = "protobuf";
        tag = "v${finalAttrs.version}";
        hash = "sha256-Y1qTHFl9xItaIs5u3mr+US1d1KmIfVJXqC7q4AA2U/w=";
      };
    }
  );
in

ghidra-extensions.buildGhidraExtension (finalAttrs: {
  pname = "binexport";
  version = "12-unstable-2026-09-10";

  src = binexportSource;

  sourceRoot = "${finalAttrs.src.name}/java";

  # Upstream resolves protoc as a Maven binary artifact, and that ELF has the
  # wrong interpreter here.
  postPatch = ''
    substituteInPlace build.gradle \
      --replace-fail 'artifact = "com.google.protobuf:protoc:''${protobufVersion}"' \
                     'path = "${lib.getExe protoc}"'

    # jgrapht-core/io 1.5.1 on Maven Central carry a zero-length ZIP extra
    # field, and Gradle 9 -- what buildGhidraExtension switched to -- refuses to
    # expand such an archive. The protobuf plugin expands every jar on the proto
    # path, which buildExtension.gradle fills with Ghidra's bundled jars, so the
    # two jgrapht ones abort the build. binexport2.proto imports nothing, so the
    # extraction has nothing to contribute. Both occurrences are the
    # extractInclude{,Test}Proto blocks. Drop once Gradle accepts them again.
    substituteInPlace build.gradle \
      --replace-fail 'dependsOn("copyDependencies")' \
                     'dependsOn("copyDependencies"); inputFiles.setFrom()'

    # Upstream pins the toolchain to 21, which matched Ghidra until 12.2 moved
    # to JDK 25 -- and buildGhidraExtension now supplies only that, so Gradle
    # finds no 21 to resolve the request against. Tracking the running JVM keeps
    # the extension on whatever Ghidra itself was built with.
    substituteInPlace build.gradle \
      --replace-fail 'JavaLanguageVersion.of(21)' \
                     'JavaLanguageVersion.of(JavaVersion.current().majorVersion)'
  '';

  # A tripwire for the pin above: if Ghidra's bundled runtime ever moves ahead
  # of protoc, the mismatch would otherwise surface only when someone runs an
  # export, as a static-initialiser failure inside Ghidra.
  preBuild = ''
    if [ ! -e "${ghidra}/lib/ghidra/Ghidra/Debug/ProposedUtils/lib/protobuf-java-4.${protoc.version}.jar" ]; then
      echo "Ghidra no longer bundles protobuf-java 4.${protoc.version}; repin protoc to match:" >&2
      ls "${ghidra}"/lib/ghidra/Ghidra/Debug/ProposedUtils/lib/protobuf-java-*.jar >&2
      exit 1
    fi
  '';

  mitmCache = gradle.fetchDeps {
    pkg = finalAttrs.finalPackage;
    data = ./deps.json;
  };

  meta = {
    description = "Ghidra extension exporting disassembly to the BinExport protocol buffer format";
    homepage = "https://github.com/google/binexport";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode # the jars Ghidra's buildExtension bundles
    ];
  };
})
