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
        version = "1.0.1"; # 与 flutter/pubspec.yaml version 字段同步
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "nekomusic";
          inherit version;
          src = self;

          # Flutter 构建会在 HOME 缓存引擎产物、pub 拉依赖 → 需要网络与可写 HOME，
          # 请在 CI/本机构建时使用：nix build --option sandbox false --impure
          # （注：flakes 默认禁用；如需纯构建可先 nix flake prefetch 各依赖）
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
          ];

          configurePhase = ''
            runHook preConfigure
            # 引擎（neko_engine/neko_core）与 flutter 均在仓库根；
            # 预跑引擎 cmake 以便更早暴露 Qt/mpv 工具链问题
            cmake -S engine -B engine/build -DCMAKE_BUILD_TYPE=Release
            cmake --build engine/build --target neko_engine neko_core --parallel
            runHook postConfigure
          '';

          buildPhase = ''
            runHook preBuild
            export HOME="$TMPDIR/flutter-home"
            mkdir -p "$HOME"
            flutter config --no-analytics
            flutter pub get
            flutter build linux --release
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            # 应用本体
            mkdir -p $out/lib/nekomusic $out/bin
            cp -r flutter/build/linux/x64/release/bundle/. $out/lib/nekomusic/
            chmod +x $out/lib/nekomusic/neko_music
            makeWrapper $out/lib/nekomusic/neko_music $out/bin/nekomusic
            # 桌面入口 + hicolor 图标（XDG_DATA_DIRS 自动对桌面环境可见；
            # Exec 走 PATH 中 nekomusic，app_id 匹配文件名即可显示任务栏图标）
            mkdir -p $out/share/applications \
                     $out/share/icons/hicolor/512x512/apps
            sed "s|^Exec=.*|Exec=nekomusic %F|" \
              packaging/com.nekomusic.neko_music.desktop \
              > $out/share/applications/com.nekomusic.neko_music.desktop
            cp packaging/icons/hicolor/512x512/apps/nekomusic.png \
              $out/share/icons/hicolor/512x512/apps/nekomusic.png
            runHook postInstall
          ''';

          meta = with pkgs.lib; {
            description = "Neko歌姬计划：高品质无损云音乐播放器（Flutter 版）";
            license = licenses.unfreeRedistributable; # TODO: 补充实际许可证
            platforms = platforms.linux;
          };
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
        };
      }
    ) // {
      # NixOS module：environment.systemPackages 安装即可
      # （包的 share/applications 与 share/icons 经 XDG_DATA_DIRS 自动暴露）
      nixosModules.default = { lib, pkgs, ... }:
        let pkg = self.packages.${pkgs.system}.default; in {
          options.services.nekomusic = lib.mkEnableOption
            "Neko歌姬计划（桌面音乐播放器）加入 systemPackages";
          config = lib.mkIf config.services.nekomusic {
            environment.systemPackages = [ pkg ];
          };
        };
    };
}
