{
  description = "A private, fast, and honest web browser";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, self }:
    let
      inherit (nixpkgs) lib;
      inherit (lib.attrsets)
        attrNames
        genAttrs
        recursiveUpdate
        ;
      inherit (lib.licenses) gpl3Only;
      inherit (lib.lists) foldl' optionals;
      inherit (lib.meta) getExe;
      inherit (lib.strings) makeLibraryPath optionalString;
      inherit (lib.systems) flakeExposed;
      inherit (lib.trivial) importJSON pathExists;

      perSystem = if pathExists ./versions.json then importJSON ./versions.json else { };

      forAllSystems = f: genAttrs flakeExposed (system: f (import nixpkgs { inherit system; }));
      forSupportedSystems =
        f: genAttrs (attrNames perSystem) (system: f (import nixpkgs { inherit system; }));

      package =
        {
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
        }:
        stdenv.mkDerivation {
          pname = "helium";
          inherit (perSystem.${stdenv.hostPlatform.system}) version;

          src = fetchurl {
            inherit (perSystem.${stdenv.hostPlatform.system}) url hash;
          };

          nativeBuildInputs =
            optionals stdenv.isDarwin [ makeBinaryWrapper ]
            ++ optionals stdenv.isLinux [
              makeWrapper
              autoPatchelfHook
              qt6.wrapQtAppsHook
            ];

          buildInputs = optionals stdenv.isLinux [
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

          # Ignore Qt5 shim, qt5webengine is unmaintained & we're using Qt6
          autoPatchelfIgnoreMissingDeps = optionals stdenv.isLinux [
            "libQt5Core.so.5"
            "libQt5Gui.so.5"
            "libQt5Widgets.so.5"
          ];

          unpackCmd = optionalString stdenv.isDarwin /* sh */ ''
            mnt=$(TMPDIR=/tmp mktemp -d -t nix-XXXXXXXXXX)
            trap "/usr/bin/hdiutil detach $mnt -force; rm -rf $mnt" EXIT
            /usr/bin/hdiutil attach -nobrowse -readonly -mountpoint $mnt $curSrc
            cp --archive $mnt/Helium.app $PWD/
          '';

          sourceRoot = optionalString stdenv.isDarwin ".";

          installPhase = ''
            runHook preInstall

            ${optionalString stdenv.isDarwin /* sh */ ''
              mkdir --parents $out/Applications
              cp --archive Helium.app $out/Applications/Helium.app

              mkdir --parents $out/bin
              makeBinaryWrapper $out/Applications/Helium.app/Contents/MacOS/Helium $out/bin/helium
            ''}

            ${optionalString stdenv.isLinux /* sh */ ''
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
            license = gpl3Only;
            mainProgram = "helium";
          };
        };
    in
    {
      checks = forSupportedSystems (pkgs: {
        print-version = pkgs.runCommand "print-version" { } ''
          ${getExe self.packages.${pkgs.stdenv.hostPlatform.system}.helium} --version | tee $out
        '';
      });

      packages = foldl' recursiveUpdate { } [
        (forSupportedSystems (pkgs: {
          helium = pkgs.callPackage package { };
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.helium;
        }))

        (forAllSystems (pkgs: {
          update-versions = pkgs.writeScriptBin "update-versions" /* nu */ ''
            #!${getExe pkgs.nushell}

            def asset-to-system [name: string]: nothing -> any {
              let row = $name | parse --regex '(?<arch>x86_64|arm64)[-_](?<os>linux|macos)\.(?:tar\.xz|dmg)$' | first
              let arch = if $row.arch == "arm64" { "aarch64" } else { "x86_64" }
              let os = if $row.os == "macos" { "darwin" } else { "linux" }
              $"($arch)-($os)"
            }

            def fetch-release [repository: string]: nothing -> list {
              let release = try { http get $"https://api.github.com/repos/($repository)/releases/latest" } catch { |err|
                print --stderr $"($repository): /releases/latest failed"
                print --stderr $err.rendered
                exit 1
              }

              $release.assets
              | each {|asset| {
                name: $asset.name,
                version: $release.tag_name,
                url: $asset.browser_download_url
              } }
            }

            def main [path: path] {
              let olds = try { open --raw $path | from json } catch { {} }

              ((fetch-release "imputnet/helium-linux") ++ (fetch-release "imputnet/helium-macos")

              # Filter-map the name field into a system field.
              | insert system {|asset| try { asset-to-system $asset.name } } | where system != null | reject name

              # Decide whether to use the new or old etag and thus hash for the item.
              | par-each --keep-order {|new|
                let old = $olds | get --optional $new.system

                let new_etag = http head $new.url
                  | where { ($in.name | str downcase) == "etag" }
                  | get --optional 0.value
                let old_etag = $old.etag?

                if $new_etag == $old_etag and $new_etag != null {
                  print --stderr $"($new.system): unchanged"

                  $new | merge { hash: $old.hash, etag: $old_etag }
                } else {
                  print --stderr $"($new.system): fetching"

                  let new_hash = ^${getExe pkgs.nix} store prefetch-file --json $new.url | from json | get hash
                  $new | merge { hash: $new_hash, etag: $new_etag }
                }
              }

              # Turn into a record keyed by the system.
              | each {|item| { ($item.system): ($item | reject system) } } | into record

              # Merge it into existing old.
              | collect {|news| $olds | merge $news }

              # Save.
              | to json | save --force $path)
            }
          '';
        }))
      ];
    };
}
