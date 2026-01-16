{
  description = "Helium - A private, fast, and honest web browser";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    inputs:
    let
      inherit (inputs) nixpkgs self;
      inherit (nixpkgs) lib;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs platforms;

      version = "0.7.7.1";

      linuxHashes = {
        "x86_64-linux" = "sha256-aY9GwIDPTcskm55NluSyxkCHC6drd6BdBaNYZhrzlRE=";
        "aarch64-linux" = "sha256-76hJ19/bHzdE1//keGF9imYkMHOy6VHpA56bxEkgwgA=";
      };

      darwinHashes = {
        "x86_64-darwin" = "sha256-LtxzeBkECRML+q+qtcTljuFoPefuZdk1PIcdDqSGl0Y=";
        "aarch64-darwin" = "sha256-iFE2OigeG+sDfGKmuqqb6LKUyxhZ2Jcti+jLzeHMLYM=";
      };

      mkHeliumLinux =
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
        in
        pkgs.stdenv.mkDerivation {
          pname = "helium";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-${
              if system == "aarch64-linux" then "arm64" else "x86_64"
            }_linux.tar.xz";
            sha256 = linuxHashes.${system};
          };

          nativeBuildInputs = with pkgs; [
            makeWrapper
            autoPatchelfHook
            qt6.wrapQtAppsHook
          ];

          buildInputs = with pkgs; [
            glib
            gdk-pixbuf
            gtk3
            nspr
            nss
            dbus
            atk
            at-spi2-atk
            cups
            expat
            libxcb
            libxkbcommon
            at-spi2-core
            xorg.libX11
            xorg.libXcomposite
            xorg.libXdamage
            xorg.libXext
            xorg.libXfixes
            xorg.libXrandr
            mesa
            cairo
            pango
            systemd
            alsa-lib
            libdrm
            qt6.qtbase
          ];

          # Ignore Qt5 shim, qt5webengine is unmaintained & we're using Qt6
          autoPatchelfIgnoreMissingDeps = [
            "libQt5Core.so.5"
            "libQt5Gui.so.5"
            "libQt5Widgets.so.5"
          ];

          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin $out/opt/helium
            cp -r ./* $out/opt/helium/

            makeWrapper $out/opt/helium/chrome-wrapper $out/bin/helium \
              --prefix LD_LIBRARY_PATH : "${
                lib.makeLibraryPath [
                  pkgs.libGL
                  pkgs.libva
                  pkgs.pipewire
                  pkgs.libpulseaudio
                ]
              }"

            mkdir -p $out/share/applications
            cp $out/opt/helium/helium.desktop $out/share/applications/
            substituteInPlace $out/share/applications/helium.desktop \
              --replace-fail 'chromium' 'helium'

            mkdir -p $out/share/pixmaps
            cp $out/opt/helium/product_logo_256.png $out/share/pixmaps/helium.png

            runHook postInstall
          '';

          meta = {
            inherit platforms;
            description = "A private, fast, and honest web browser";
            homepage = "https://github.com/imputnet/helium-linux";
            license = lib.licenses.gpl3Only;
            mainProgram = "helium";
          };
        };

      mkHeliumDarwin =
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
        in
        pkgs.stdenv.mkDerivation {
          pname = "helium";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://github.com/imputnet/helium-macos/releases/download/${version}/helium_${version}_${
              if system == "aarch64-darwin" then "arm64" else "x86_64"
            }-macos.dmg";
            sha256 = darwinHashes.${system};
          };

          # The DMG is XZ-compressed with APFS inside, which undmg doesn't support.
          # Use 7zz which handles this format correctly.
          nativeBuildInputs = [ pkgs._7zz ];

          unpackPhase = ''
            runHook preUnpack
            7zz x $src -o$TMPDIR/extract -y
            runHook postUnpack
          '';

          sourceRoot = ".";

          installPhase = ''
            runHook preInstall

            mkdir -p $out/Applications
            cp -r $TMPDIR/extract/Helium.app $out/Applications/Helium.app

            mkdir -p $out/bin
            cat > $out/bin/helium << EOF
            #!/bin/bash
            exec $out/Applications/Helium.app/Contents/MacOS/Helium "\$@"
            EOF
            chmod +x $out/bin/helium

            runHook postInstall
          '';

          meta = {
            inherit platforms;
            description = "A private, fast, and honest web browser";
            homepage = "https://github.com/imputnet/helium-macos";
            license = lib.licenses.gpl3Only;
            mainProgram = "helium";
          };
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          isDarwin = builtins.elem system [
            "x86_64-darwin"
            "aarch64-darwin"
          ];
        in
        {
          helium = if isDarwin then mkHeliumDarwin pkgs else mkHeliumLinux pkgs;

          default = self.packages.${system}.helium;
        }
      );
    };
}
