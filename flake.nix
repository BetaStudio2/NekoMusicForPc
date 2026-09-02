{
  description = "Neko歌姬计划 — Flutter 无损云音乐播放器";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        version = "1.0.1";
      in
      {
        packages = {
          default = pkgs.stdenv.mkDerivation {
            pname = "nekomusic";
            inherit version;
            src = self;

            nativeBuildInputs = with pkgs; [
              flutter
              clang
              cmake
              ninja
              pkg-config
              qt6.wrapQtAppsHook
              makeWrapper
            ];

            buildInputs = with pkgs; [
              qt6.qtbase
              mpv
              gtk3
              libayatana-appindicator  # tray_manager 插件构建/运行依赖
            ];

            # 引擎与 Flutter 均需联网（pub 拉依赖、Flutter 下引擎产物），
            # 请在 CI/本机构建使用：nix build --option sandbox false --impure
            phases = [ "unpackPhase" "patchPhase" "configurePhase" "buildPhase" "installPhase" ];

            configurePhase = ''
              runHook preConfigure
              cmake -S engine -B engine/build -DCMAKE_BUILD_TYPE=Release
              cmake --build engine/build --target neko_engine neko_core --parallel
              runHook postConfigure
            '';

            buildPhase = ''
              runHook preBuild
              export HOME="$TMPDIR/flutter-home"
              mkdir -p "$HOME"
              flutter config --no-analytics
              # Dart 工程根为 flutter/；子 shell 内执行以免 cwd 影响后续 installPhase
              (cd flutter && flutter pub get && flutter build linux --release)
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib/nekomusic $out/bin
              cp -r flutter/build/linux/x64/release/bundle/. $out/lib/nekomusic/
              chmod +x $out/lib/nekomusic/neko_music
              makeWrapper $out/lib/nekomusic/neko_music $out/bin/nekomusic

              mkdir -p $out/share/applications $out/share/icons/hicolor/512x512/apps
              sed -e "s|^Exec=.*|Exec=nekomusic %F|" \
                  packaging/com.nekomusic.neko_music.desktop \
                  > $out/share/applications/com.nekomusic.neko_music.desktop
              cp packaging/icons/hicolor/512x512/apps/nekomusic.png \
                 $out/share/icons/hicolor/512x512/apps/nekomusic.png
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "Neko歌姬计划：高品质无损云音乐播放器（Flutter 版）";
              license = licenses.agpl3Plus;
              platforms = platforms.linux;
            };
          };
        };
      });
}
