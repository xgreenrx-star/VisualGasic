; VisualGasic Windows installer — NSIS script
;
; Produces an .exe that:
;   1. Installs to %LocalAppData%\VisualGasic\Installer  (no admin required)
;   2. Unpacks an embeddable Python runtime, the bootstrap script, and the
;      VisualGasic addon alongside it
;   3. Runs bootstrap_vg.py which downloads Godot 4.6.1+ (user-selectable),
;      scaffolds a "MyFirstGame" project, creates Start Menu + Desktop
;      shortcuts, and registers the .vg file type
;   4. Provides a matching uninstaller
;
; Build with:
;   bash scripts/build_windows_installer.sh <version>
; The build wrapper downloads the Python embeddable zip and VG + addon
; payload, then invokes makensis on this file.

!define APP_NAME        "VisualGasic"
!define APP_PUBLISHER   "VisualGasic Project"
!define APP_URL         "https://github.com/xgreenrx-star/VisualGasic"
!define LAUNCHER_NAME   "VisualGasic IDE"
!define INSTALLER_NAME  "VisualGasic Installer"

; Version is passed in via /DVERSION=x.y.z on the makensis command line.
!ifndef VERSION
    !define VERSION "dev"
!endif

; BUILD_DIR holds the staged payload (bootstrap_vg.py, addon, python/).
; Passed in via /DBUILD_DIR=path on the makensis command line.
!ifndef BUILD_DIR
    !define BUILD_DIR "build\win"
!endif

; OUTPUT_FILE is the final .exe path.
!ifndef OUTPUT_FILE
    !define OUTPUT_FILE "VisualGasic-Installer-v${VERSION}-x86_64.exe"
!endif

Name                "${APP_NAME} Installer v${VERSION}"
OutFile             "${OUTPUT_FILE}"
InstallDir          "$LOCALAPPDATA\VisualGasic\Installer"
InstallDirRegKey   HKCU "Software\${APP_NAME}" "InstallerDir"
RequestExecutionLevel user
ShowInstDetails     show
ShowUninstDetails   show
SetCompressor       /SOLID lzma

; ── Modern UI ────────────────────────────────────────────────────────────
!include "MUI2.nsh"

!define MUI_ABORTWARNING
!define MUI_ICON   "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\run_installer.cmd"
!define MUI_FINISHPAGE_RUN_TEXT "Launch the VisualGasic first-time setup now"
!define MUI_FINISHPAGE_RUN_NOTCHECKED
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ── Install ──────────────────────────────────────────────────────────────
Section "VisualGasic first-time installer" SecMain
    SetOutPath "$INSTDIR"

    ; Payload — everything staged by scripts/build_windows_installer.sh
    File /r "${BUILD_DIR}\*.*"

    ; Small .cmd shim the user can re-run any time
    FileOpen $0 "$INSTDIR\run_installer.cmd" w
    FileWrite $0 "@echo off$\r$\n"
    FileWrite $0 "cd /d %~dp0$\r$\n"
    FileWrite $0 "python\python.exe bootstrap_vg.py --offline %~dp0offline --launch %*$\r$\n"
    FileClose $0

    ; Record the uninstaller location and run it from an uninstall context.
    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Start Menu shortcut for the *first-time installer* (users may want
    ; to re-run it, e.g. to install a different Godot version).
    CreateDirectory "$SMPROGRAMS\VisualGasic"
    CreateShortCut "$SMPROGRAMS\VisualGasic\VisualGasic first-time setup.lnk" \
        "$INSTDIR\run_installer.cmd" "" "$INSTDIR\run_installer.cmd" 0

    ; Add/Remove Programs entry (HKCU — no admin needed).
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
        "DisplayName"     "${APP_NAME} Installer (v${VERSION})"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
        "DisplayVersion"  "${VERSION}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
        "Publisher"       "${APP_PUBLISHER}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
        "URLInfoAbout"    "${APP_URL}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
        "UninstallString" "$\"$INSTDIR\Uninstall.exe$\""
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
        "InstallLocation" "$INSTDIR"
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
        "NoModify" 1
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" \
        "NoRepair" 1

    ; Stash install dir for the uninstaller.
    WriteRegStr HKCU "Software\${APP_NAME}" "InstallerDir" "$INSTDIR"
    WriteRegStr HKCU "Software\${APP_NAME}" "Version" "${VERSION}"
SectionEnd

; ── Uninstall ────────────────────────────────────────────────────────────
; Note: the first-time installer writes additional files under
; %LocalAppData%\VisualGasic\{godot,addons,bin} and may create shortcuts
; to a scaffolded project. The uninstaller only removes the installer
; payload itself; it explicitly leaves the user's project and Godot install
; alone so that scripts/data they've created aren't lost. A hint is printed.
Section "Uninstall"
    Delete "$INSTDIR\Uninstall.exe"
    Delete "$INSTDIR\run_installer.cmd"
    RMDir /r "$INSTDIR\python"
    RMDir /r "$INSTDIR\offline"
    Delete "$INSTDIR\bootstrap_vg.py"
    RMDir "$INSTDIR"

    Delete "$SMPROGRAMS\VisualGasic\VisualGasic first-time setup.lnk"
    RMDir  "$SMPROGRAMS\VisualGasic"

    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
    DeleteRegKey HKCU "Software\${APP_NAME}"

    DetailPrint ""
    DetailPrint "Note: your scaffolded VisualGasic project, Godot install,"
    DetailPrint "and .vg file association were left in place so your work"
    DetailPrint "is not lost. To remove them manually, delete:"
    DetailPrint "  %LOCALAPPDATA%\VisualGasic"
    DetailPrint "  %USERPROFILE%\VisualGasic"
    DetailPrint "and run:  reg delete HKCU\Software\Classes\.vg /f"
SectionEnd
