; Neko歌姬计划 — Windows 安装脚本
; 用 makensis（NSIS 3.x）编译；CI: scripts\build.bat release 后调用
;   makensis /DVERSION=1.0.1 /DOUT=nekomusic-setup-1.0.1.exe /DSTAGING=build\windows\x64\runner\Release nekomusic.nsi
Unicode true
!ifndef VERSION
  !define VERSION "1.0.1"
!endif
!ifndef STAGING
  !error "缺少 /DSTAGING=<flutter windows release 目录>"
!endif

Name "Neko歌姬计划"
OutFile "${OUT}"
InstallDir "$PROGRAMFILES64\NekoMusic"
RequestExecutionLevel admin
SetCompressor /SOLID lzma

; ── 卸载器与注册表 ──
!define APPID "com.nekomusic.neko_music"
!define REGUNINST "Software\Microsoft\Windows\CurrentVersion\Uninstall\NekoMusic"

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "${STAGING}\*.*"

  ; 卸载器
  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "${REGUNINST}" "DisplayName" "Neko歌姬计划"
  WriteRegStr HKLM "${REGUNINST}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${REGUNINST}" "Publisher" "BetaStudio2"
  WriteRegStr HKLM "${REGUNINST}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKLM "${REGUNINST}" "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKLM "${REGUNINST}" "NoModify" 1
  WriteRegDWORD HKLM "${REGUNINST}" "NoRepair" 1

  ; 快捷方式
  CreateDirectory "$SMPROGRAMS\NekoMusic"
  CreateShortcut "$SMPROGRAMS\NekoMusic\Neko歌姬计划.lnk" "$INSTDIR\neko_music.exe"
  CreateShortcut "$DESKTOP\Neko歌姬计划.lnk" "$INSTDIR\neko_music.exe"
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\Neko歌姬计划.lnk"
  RMDir /r "$SMPROGRAMS\NekoMusic"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKLM "${REGUNINST}"
SectionEnd
