# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
{
  stdenvNoCC,
  lib,
  requireFile,
  unzip,
  jdk21,
  openjfx21,
  makeWrapper,
  buildFHSEnv,
  makeDesktopItem,
  writeShellScript,
  symlinkJoin,
}:

let
  version = "2.22.0";

  desktopItem = makeDesktopItem {
    name = "STM32CubeProgrammer";
    # Must match the FHS wrapper binary name (pname of the GUI env below) —
    # desktop Exec lookup is case-sensitive.
    exec = "stm32cubeprogrammer";
    tryExec = "stm32cubeprogrammer";
    desktopName = "STM32CubeProgrammer";
    categories = [ "Development" ];
    comment = "STM32 device programming tool";
    terminal = false;
    startupNotify = false;
  };

  package = stdenvNoCC.mkDerivation {
    pname = "stm32cubeprogrammer-unwrapped";
    inherit version;

    # Register with: nix-store --add-fixed sha256 <zip>
    src = requireFile {
      name = "SetupSTM32CubeProgrammer_linux_64.zip";
      url = "https://www.st.com/en/development-tools/stm32cubeprog.html";
      hash = "sha256-//oBertNoUWC4Smqmh5Ph+bQcZo8uVDAGE9MtIq2Cqc=";
    };

    nativeBuildInputs = [
      unzip
      makeWrapper
      jdk21
    ];

    dontConfigure = true;
    dontPatchELF = true;
    dontStrip = true;

    unpackPhase = ''
      runHook preUnpack
      unzip $src
      runHook postUnpack
    '';

    buildPhase = ''
      runHook preBuild

      # Panel IDs extracted from resources/panelsOrder in the installer JAR
      cat > auto-install.xml << AUTOXML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <AutomatedInstallation langpack="eng">
          <com.st.CustomPanels.CheckedHelloPorgrammerPanel id="Hello.panel"/>
          <com.izforge.izpack.panels.info.InfoPanel id="Info.panel"/>
          <com.izforge.izpack.panels.licence.LicencePanel id="Licence.panel"/>
          <com.st.CustomPanels.TargetProgrammerPanel id="target.panel">
              <installpath>$TMPDIR/stm32cubeprog-install</installpath>
          </com.st.CustomPanels.TargetProgrammerPanel>
          <com.st.CustomPanels.AnalyticsPanel id="analytics.panel">
              <entry key="Analytics" value="Disable"/>
          </com.st.CustomPanels.AnalyticsPanel>
          <com.st.CustomPanels.PacksProgrammerPanel id="Packs.panel">
              <pack index="0" name="Core Files" selected="true"/>
              <pack index="1" name="STM32CubeProgrammer" selected="true"/>
              <pack index="2" name="STM32TrustedPackageCreator" selected="true"/>
          </com.st.CustomPanels.PacksProgrammerPanel>
          <com.izforge.izpack.panels.install.InstallPanel id="Install.panel"/>
          <com.izforge.izpack.panels.shortcut.ShortcutPanel id="Shortcut.panel"/>
          <com.st.CustomPanels.FinishProgrammerPanel id="finish.panel"/>
      </AutomatedInstallation>
      AUTOXML

      # HOME must be writable because the installer tries to modify .bashrc
      export HOME="$TMPDIR/fakehome"
      mkdir -p "$HOME"
      touch "$HOME/.bashrc"

      java -jar SetupSTM32CubeProgrammer-${version}.exe auto-install.xml \
        || true  # Installer may return non-zero even on success

      test -d "$TMPDIR/stm32cubeprog-install/bin" \
        || (echo "Installation failed: bin directory not found"; exit 1)

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      local installDir="$TMPDIR/stm32cubeprog-install"

      mkdir -p $out/opt/STM32CubeProgrammer
      cp -r "$installDir"/. $out/opt/STM32CubeProgrammer/

      # The JRE sits alongside the installer in the zip, not in the install target.
      cp -r jre $out/opt/STM32CubeProgrammer/jre

      chmod +x $out/opt/STM32CubeProgrammer/bin/STM32_Programmer_CLI \
               $out/opt/STM32CubeProgrammer/bin/STM32_SigningTool_CLI \
               $out/opt/STM32CubeProgrammer/bin/STM32TrustedPackageCreator_CLI \
        2>/dev/null || true

      if [ -d "$installDir/Drivers/rules" ]; then
        mkdir -p $out/lib/udev/rules.d
        cp "$installDir"/Drivers/rules/*.rules $out/lib/udev/rules.d/
      fi

      # JDK 21's --module-path requires JARs, not exploded class dirs
      mkdir -p $out/opt/STM32CubeProgrammer/javafx-modules
      for mod in ${openjfx21}/modules/javafx.*; do
        modname=$(basename "$mod")
        jar --create --file "$out/opt/STM32CubeProgrammer/javafx-modules/$modname.jar" -C "$mod" .
      done

      mkdir -p $out/share/applications
      cp ${desktopItem}/share/applications/*.desktop $out/share/applications/

      runHook postInstall
    '';

    meta = {
      description = "All-in-one software tool to program STM32 devices";
      longDescription = ''
        STM32CubeProgrammer provides an all-in-one software tool to program
        STM32 devices in any environment: multi-OS, graphical user interface,
        or command line interface. It supports JTAG, SWD, USB, UART, SPI,
        CAN, and I2C connections.
      '';
      homepage = "https://www.st.com/en/development-tools/stm32cubeprog.html";
      sourceProvenance = with lib.sourceTypes; [
        binaryNativeCode
        binaryBytecode
      ];
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };

  fhsTargetPkgs =
    pkgs: with pkgs; [
      libusb1
      udev

      libGL
      libdrm
      libgbm
      libxkbcommon
      libx11
      libxrender
      libxrandr
      libxcb
      libxext
      libxfixes
      libxcomposite
      libxdamage
      libxi
      libxcursor
      libxtst
      freetype
      fontconfig
      xrdb

      gtk3
      glib
      pango
      cairo
      at-spi2-atk
      dbus

      openssl
      krb5

      zlib
      cups
      nspr
      nss
      expat
      alsa-lib
    ];

  mkFHSWrapper =
    {
      pname,
      runScript,
      extraCommands ? "",
    }:
    buildFHSEnv {
      inherit pname version;
      inherit (package) meta;
      inherit runScript;
      targetPkgs = fhsTargetPkgs;
      extraInstallCommands = extraCommands;
    };

  gui = mkFHSWrapper {
    pname = "stm32cubeprogrammer";
    runScript = writeShellScript "stm32cubeprogrammer-gui" ''
      export LD_LIBRARY_PATH="${package}/opt/STM32CubeProgrammer/lib:${openjfx21}/modules_libs/javafx.graphics:${openjfx21}/modules_libs/javafx.media:${openjfx21}/modules_libs/javafx.base''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

      cd "${package}/opt/STM32CubeProgrammer/bin"

      # GDK_SCALE works at the GTK level for XWayland apps; override with
      # STM32CUBEPROG_SCALE (try 3 on HiDPI).
      export GDK_SCALE=''${STM32CUBEPROG_SCALE:-1}
      export GDK_DPI_SCALE=1

      exec ${jdk21}/bin/java \
        --module-path "${package}/opt/STM32CubeProgrammer/javafx-modules" \
        --add-modules javafx.controls,javafx.fxml,javafx.swing,javafx.graphics \
        --add-opens javafx.graphics/com.sun.javafx.css=ALL-UNNAMED \
        --add-opens javafx.graphics/com.sun.glass.ui=ALL-UNNAMED \
        --add-opens javafx.graphics/com.sun.javafx.application=ALL-UNNAMED \
        --add-opens javafx.base/com.sun.javafx.runtime=ALL-UNNAMED \
        --add-exports javafx.graphics/com.sun.glass.ui=ALL-UNNAMED \
        --add-exports javafx.graphics/com.sun.javafx.application=ALL-UNNAMED \
        -jar "${package}/opt/STM32CubeProgrammer/bin/STM32CubeProgrammerLauncher" "$@"
    '';
    extraCommands = ''
      mkdir -p $out/share/applications
      ln -sf ${package}/share/applications/* $out/share/applications/

      if [ -d "${package}/lib/udev" ]; then
        mkdir -p $out/lib/udev
        ln -sf ${package}/lib/udev/* $out/lib/udev/
      fi
    '';
  };

  cli = mkFHSWrapper {
    pname = "STM32_Programmer_CLI";
    runScript = writeShellScript "stm32-programmer-cli" ''
      export LD_LIBRARY_PATH="${package}/opt/STM32CubeProgrammer/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      cd "${package}/opt/STM32CubeProgrammer/bin"
      exec "${package}/opt/STM32CubeProgrammer/bin/STM32_Programmer_CLI" "$@"
    '';
  };

  signingCli = mkFHSWrapper {
    pname = "STM32_SigningTool_CLI";
    runScript = writeShellScript "stm32-signingtool-cli" ''
      export LD_LIBRARY_PATH="${package}/opt/STM32CubeProgrammer/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      cd "${package}/opt/STM32CubeProgrammer/bin"
      exec "${package}/opt/STM32CubeProgrammer/bin/STM32_SigningTool_CLI" "$@"
    '';
  };

  tpc = mkFHSWrapper {
    pname = "STM32TrustedPackageCreator";
    runScript = writeShellScript "stm32-tpc" ''
      export LD_LIBRARY_PATH="${package}/opt/STM32CubeProgrammer/lib:${openjfx21}/modules_libs/javafx.graphics:${openjfx21}/modules_libs/javafx.media:${openjfx21}/modules_libs/javafx.base''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

      cd "${package}/opt/STM32CubeProgrammer/bin"

      scale=''${GDK_SCALE:-1}
      if command -v xrdb >/dev/null 2>&1; then
        dpi=$(xrdb -query 2>/dev/null | grep -i "Xft.dpi" | awk '{print $2}')
        if [ -n "$dpi" ] && [ "$dpi" -gt 96 ] 2>/dev/null; then
          scale=$(( dpi / 96 ))
        fi
      fi

      exec ${jdk21}/bin/java \
        --module-path "${package}/opt/STM32CubeProgrammer/javafx-modules" \
        --add-modules javafx.controls,javafx.fxml,javafx.swing,javafx.graphics \
        --add-opens javafx.graphics/com.sun.javafx.css=ALL-UNNAMED \
        --add-opens javafx.graphics/com.sun.glass.ui=ALL-UNNAMED \
        --add-opens javafx.graphics/com.sun.javafx.application=ALL-UNNAMED \
        --add-opens javafx.base/com.sun.javafx.runtime=ALL-UNNAMED \
        --add-exports javafx.graphics/com.sun.glass.ui=ALL-UNNAMED \
        --add-exports javafx.graphics/com.sun.javafx.application=ALL-UNNAMED \
        -Dglass.gtk.uiScale="$scale" \
        -jar "${package}/opt/STM32CubeProgrammer/bin/STM32TrustedPackageCreator" "$@"
    '';
  };
in
symlinkJoin {
  name = "stm32cubeprogrammer-${version}";
  paths = [
    gui
    cli
    signingCli
    tpc
  ];
  passthru = {
    unwrapped = package;
    inherit
      gui
      cli
      signingCli
      tpc
      ;
  };
  inherit (package) meta;
}
