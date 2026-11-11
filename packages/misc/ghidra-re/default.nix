# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
{
  ghidra,
  ghidra-binexport,
}:

ghidra.withExtensions (
  p:
  let
    # Ghidra 12.2 dropped TaskMonitor.checkCanceled, the long-deprecated
    # single-l misspelling, leaving only checkCancelled. Two call sites.
    ghidra-firmware-utils = p.ghidra-firmware-utils.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace \
          src/main/java/firmware/cbfs/CBFSFileSystem.java \
          src/main/java/firmware/uefi_fv/UEFIFirmwareVolumeHeader.java \
          --replace-fail 'monitor.checkCanceled();' 'monitor.checkCancelled();'
      '';
    });

    # Ghidra 12.2 removed ClangToken.setHighlight, and that one call is
    # lightkeeper's only use of it. DecompilerPanel.addSecondaryHighlight is the
    # surviving way to colour a specific token, and DisassemblyController
    # already holds the panel it needs.
    lightkeeper = p.lightkeeper.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace lightkeeper/src/main/java/lightkeeper/controller/DisassemblyController.java \
          --replace-fail 'tokens.stream().forEach(t -> t.setHighlight(this.color));' \
                         'tokens.stream().forEach(t -> dpanel.addSecondaryHighlight(t, this.color));'
      '';
    });

    # FileSystemIndexHelper.storeFile declares IOException as of Ghidra 12.2,
    # and this is Ghidra's own skeleton template that reva never filled in --
    # mount() iterates a ten-element array of nulls. Its one caller, the
    # factory's create(), already declares IOException.
    reva = p.reva.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/main/java/reva/revaFileSystem.java \
          --replace-fail 'public void mount(TaskMonitor monitor) {' \
                         'public void mount(TaskMonitor monitor) throws IOException {'
      '';
    });
  in
  # The three patches above are ports to the 12.2 API that upstream has not
  # made; drop each one once its extension targets Ghidra 12.2 itself.
  [
    p.findcrypt
    ghidra-firmware-utils
    p.ghidra-golanganalyzerextension
    p.ghidraninja-ghidra-scripts
    p.kaiju
    lightkeeper
    p.ret-sync
    reva
    # ghidra-extensions.wasm is marked broken in this pin.
  ]
  # Not in nixpkgs, and the one thing here that writes the .BinExport files
  # bindiff reads.
  ++ [ ghidra-binexport ]
)
