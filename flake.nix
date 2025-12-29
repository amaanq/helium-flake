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
      ];
      forAllSystems = lib.genAttrs platforms;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          helium = pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "helium";
            version = "0.7.7.1";

            src = pkgs.fetchurl {
              url = "https://github.com/imputnet/helium-linux/releases/download/${finalAttrs.version}/${finalAttrs.pname}-${finalAttrs.version}-${
                if system == "aarch64-linux" then "arm64" else "x86_64"
              }_linux.tar.xz";
              sha256 =
                if system == "aarch64-linux" then
                  "sha256-76hJ19/bHzdE1//keGF9imYkMHOy6VHpA56bxEkgwgA="
                else
                  "sha256-aY9GwIDPTcskm55NluSyxkCHC6drd6BdBaNYZhrzlRE=";
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
          });

          default = self.packages.${system}.helium;
        }
      );
    };
}
