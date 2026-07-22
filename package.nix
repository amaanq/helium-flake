{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  makeBinaryWrapper,
  autoPatchelfHook,
  qt6,
  glib,
  gdk-pixbuf,
  gtk3,
  nspr,
  nss,
  dbus,
  atk,
  at-spi2-atk,
  cups,
  expat,
  libxcb,
  libxkbcommon,
  at-spi2-core,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  mesa,
  cairo,
  pango,
  systemd,
  alsa-lib,
  libdrm,
  libGL,
  libva,
  pipewire,
  libpulseaudio,
  perSystem ?
    if lib.trivial.pathExists ./versions.json then lib.trivial.importJSON ./versions.json else { },
}:
let
  inherit (stdenv.hostPlatform) system isDarwin isLinux;
  inherit (lib.lists) optionals;
  inherit (lib.attrsets) getAttr attrNames;
  inherit (lib.strings) optionalString makeLibraryPath;

  currentSystem = getAttr system perSystem;
in
stdenv.mkDerivation {
  pname = "helium";
  inherit (currentSystem) version;

  src = fetchurl { inherit (currentSystem) url hash; };

  nativeBuildInputs =
    if isDarwin then
      [ makeBinaryWrapper ]
    else if isLinux then
      [
        makeWrapper
        autoPatchelfHook
      ]
    else
      [ ];

  buildInputs = optionals isLinux [
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
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    mesa
    cairo
    pango
    systemd
    alsa-lib
    libdrm
    qt6.qtbase
  ];

  dontWrapQtApps = true;

  # Ignore Qt5 shim, qt5webengine is unmaintained & we're using Qt6
  autoPatchelfIgnoreMissingDeps = optionals isLinux [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
  ];

  unpackCmd = optionalString isDarwin /* sh */ ''
    mnt=$(TMPDIR=/tmp mktemp -d -t nix-XXXXXXXXXX)
    trap "/usr/bin/hdiutil detach $mnt -force; rm -rf $mnt" EXIT
    /usr/bin/hdiutil attach -nobrowse -readonly -mountpoint $mnt $curSrc
    cp --archive $mnt/Helium.app $PWD/
  '';

  sourceRoot = optionalString isDarwin ".";

  installPhase = ''
    runHook preInstall

    ${optionalString isDarwin /* sh */ ''
      mkdir --parents $out/Applications
      cp --archive Helium.app $out/Applications/Helium.app

      mkdir --parents $out/bin
      makeBinaryWrapper $out/Applications/Helium.app/Contents/MacOS/Helium $out/bin/helium
    ''}

    ${optionalString isLinux /* sh */ ''
      mkdir --parents $out/opt/helium
      cp --recursive ./* $out/opt/helium/

      mkdir --parents $out/bin
      makeWrapper $out/opt/helium/helium-wrapper $out/bin/helium \
        --prefix LD_LIBRARY_PATH : "${
          makeLibraryPath [
            libGL
            libva
            pipewire
            libpulseaudio
          ]
        }"

      mkdir --parents $out/share/applications
      cp $out/opt/helium/helium.desktop $out/share/applications/

      mkdir --parents $out/share/pixmaps
      cp $out/opt/helium/product_logo_256.png $out/share/pixmaps/helium.png
    ''}

    runHook postInstall
  '';

  meta = {
    platforms = attrNames perSystem;
    description = "A private, fast, and honest web browser";
    homepage = "https://github.com/imputnet/helium";
    license = lib.licenses.gpl3Only;
    mainProgram = "helium";
  };
}
