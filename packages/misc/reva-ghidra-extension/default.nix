# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# ReVa publishes one prebuilt extension zip per Ghidra release. There is a 12.1
# asset but no 12.1.2 one, and Ghidra refuses an extension whose
# extension.properties version differs from the running application -- so the
# zip is restamped below.
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  ghidra,
}:

let
  version = "7.3.0";
  ghidraSeries = lib.versions.majorMinor ghidra.version;
in
assert lib.assertMsg (ghidraSeries == "12.1") ''
  ReVa ${version} ships prebuilt extensions for Ghidra 12.0-12.1, but nixpkgs
  has Ghidra ${ghidra.version}. Pick the matching asset from
  https://github.com/cyberkaida/reverse-engineering-assistant/releases
  (or a newer ReVa release) and update this package.
'';
stdenvNoCC.mkDerivation {
  pname = "ghidra-extension-reva";
  inherit version;

  src = fetchurl {
    url = "https://github.com/cyberkaida/reverse-engineering-assistant/releases/download/v${version}/ghidra_12.1_PUBLIC_20260613_reverse-engineering-assistant.zip";
    hash = "sha256-rCYNj7g5Fos4G2Jgj9mAIuXQS5jkhjn3V0Mqj0JAa0U=";
  };

  nativeBuildInputs = [ unzip ];
  dontUnpack = true;

  # Same layout contract as nixpkgs' buildGhidraExtension.
  installPhase = ''
    runHook preInstall

    ext="$out/lib/ghidra/Ghidra/Extensions"
    mkdir -p "$ext"
    unzip -q -d "$ext" "$src"

    props="$ext/reverse-engineering-assistant/extension.properties"
    [ -f "$props" ] || {
      echo "unexpected zip layout, expected reverse-engineering-assistant/extension.properties, got:" >&2
      ls -la "$ext" >&2
      exit 1
    }

    sed -i 's/^version=.*/version=${ghidra.version}/' "$props"
    grep -qx 'version=${ghidra.version}' "$props"

    # Stop Ghidra creating plugin lock files inside the read-only store.
    touch "$ext/reverse-engineering-assistant/.dbDirLock"

    runHook postInstall
  '';

  meta = {
    description = "ReVa - Ghidra MCP server for AI-assisted reverse engineering";
    homepage = "https://github.com/cyberkaida/reverse-engineering-assistant";
    license = lib.licenses.asl20;
    platforms = ghidra.meta.platforms;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}
