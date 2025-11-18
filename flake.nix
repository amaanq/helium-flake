{
  description = "Helium - A private, fast, and honest web browser";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs platforms;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          inherit (pkgs) lib;
        in
        {
          helium =
            let
              pname = "helium";
              version = "0.6.4.1";
            in
            pkgs.stdenv.mkDerivation {
              inherit pname version;

              src = pkgs.fetchurl {
                url = "https://github.com/imputnet/helium-linux/releases/download/${version}/${pname}-${version}-${
                  if system == "aarch64-linux" then "arm64" else "x86_64"
                }_linux.tar.xz";
                sha256 =
                  if system == "aarch64-linux" then
                    "sha256-S5kF+K2Kwhqa0GG691NvnU/2frUCWL9BKrVK7y3bzSE="
                  else
                    "sha256-9xEVnGym579rR6RunS4HWYV3nLk1ODEIGfg8PtNDSUk=";
              };

              nativeBuildInputs = [
                pkgs.makeWrapper
                pkgs.autoPatchelfHook
                pkgs.qt6.wrapQtAppsHook
              ];

              buildInputs = [
                pkgs.glib
                pkgs.gdk-pixbuf
                pkgs.gtk3
                pkgs.nspr
                pkgs.nss
                pkgs.dbus
                pkgs.atk
                pkgs.at-spi2-atk
                pkgs.cups
                pkgs.expat
                pkgs.libxcb
                pkgs.libxkbcommon
                pkgs.at-spi2-core
                pkgs.xorg.libX11
                pkgs.xorg.libXcomposite
                pkgs.xorg.libXdamage
                pkgs.xorg.libXext
                pkgs.xorg.libXfixes
                pkgs.xorg.libXrandr
                pkgs.mesa
                pkgs.cairo
                pkgs.pango
                pkgs.systemd
                pkgs.alsa-lib
                pkgs.libdrm
                pkgs.qt6.qtbase
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
                description = "A lightweight music streaming service client";
                homepage = "https://github.com/imputnet/helium-linux";
                license = lib.licenses.gpl3Only;
                mainProgram = "helium";
              };
            };

          default = self.packages.${system}.helium;
        }
      );

      defaultPackage = forAllSystems (system: self.packages.${system}.default);
    };
}
