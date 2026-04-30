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

; ── Modern UI + custom dialogs ──────────────────────────────────────────
!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "LogicLib.nsh"

!define MUI_ABORTWARNING
!define MUI_ICON   "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

; Variables collected by the wizard pages and passed to bootstrap_vg.py.
Var GodotVersion
Var ProjectName
Var ProjectFolder
Var OpenAIKey
Var ClaudeKey
Var GeminiKey
Var MakeShortcuts
Var RegisterVgFiles

Var hCtlGodot
Var hCtlProjName
Var hCtlProjFolder
Var hCtlBrowse
Var hCtlShortcuts
Var hCtlFileAssoc
Var hCtlOpenAI
Var hCtlClaude
Var hCtlGemini

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
Page custom OptionsPage OptionsPageLeave
Page custom AIKeysPage  AIKeysPageLeave
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_TEXT "VisualGasic has been installed.$\r$\n$\r$\nThe VisualGasic IDE should now be open — if not, find it on your Start Menu."
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchVgIde
!define MUI_FINISHPAGE_RUN_TEXT "Launch VisualGasic IDE now"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ── Defaults ────────────────────────────────────────────────────────────
Function .onInit
    StrCpy $GodotVersion    "4.6.1-stable"
    StrCpy $ProjectName     "My First Game"
    StrCpy $ProjectFolder   "$PROFILE\VisualGasic\MyFirstGame"
    StrCpy $MakeShortcuts   "1"
    StrCpy $RegisterVgFiles "1"
    StrCpy $OpenAIKey ""
    StrCpy $ClaudeKey ""
    StrCpy $GeminiKey ""
FunctionEnd

; ── Custom page 1: VisualGasic options ──────────────────────────────────
Function OptionsPage
    !insertmacro MUI_HEADER_TEXT "VisualGasic Options" \
        "Choose your Godot version and starter project location."

    nsDialogs::Create 1018
    Pop $0
    ${If} $0 == error
        Abort
    ${EndIf}

    ${NSD_CreateLabel} 0 0 100% 12u "Godot version:"
    Pop $0
    ${NSD_CreateDropList} 0 14u 60% 60u ""
    Pop $hCtlGodot
    SendMessage $hCtlGodot ${CB_ADDSTRING} 0 "STR:4.6.1-stable (recommended)"
    SendMessage $hCtlGodot ${CB_ADDSTRING} 0 "STR:4.6.2-stable"
    SendMessage $hCtlGodot ${CB_SETCURSEL} 0 0

    ${NSD_CreateLabel} 0 34u 100% 12u "Starter project name:"
    Pop $0
    ${NSD_CreateText} 0 48u 100% 12u "$ProjectName"
    Pop $hCtlProjName

    ${NSD_CreateLabel} 0 68u 100% 12u "Starter project folder:"
    Pop $0
    ${NSD_CreateText} 0 82u 80% 12u "$ProjectFolder"
    Pop $hCtlProjFolder
    ${NSD_CreateButton} 82% 82u 18% 12u "Browse..."
    Pop $hCtlBrowse
    ${NSD_OnClick} $hCtlBrowse OnBrowseProj

    ${NSD_CreateCheckbox} 0 106u 100% 12u "Create Start Menu and Desktop shortcuts"
    Pop $hCtlShortcuts
    ${NSD_Check} $hCtlShortcuts

    ${NSD_CreateCheckbox} 0 120u 100% 12u "Open .vg files in VisualGasic (register file type)"
    Pop $hCtlFileAssoc
    ${NSD_Check} $hCtlFileAssoc

    nsDialogs::Show
FunctionEnd

Function OnBrowseProj
    Pop $0
    nsDialogs::SelectFolderDialog "Choose a parent folder for your project" "$PROFILE"
    Pop $0
    ${If} $0 != error
        ${NSD_SetText} $hCtlProjFolder "$0\MyFirstGame"
    ${EndIf}
FunctionEnd

Function OptionsPageLeave
    ${NSD_GetText} $hCtlGodot $0
    ${If} $0 == "4.6.1-stable (recommended)"
        StrCpy $GodotVersion "4.6.1-stable"
    ${Else}
        StrCpy $GodotVersion $0
    ${EndIf}

    ${NSD_GetText} $hCtlProjName   $ProjectName
    ${NSD_GetText} $hCtlProjFolder $ProjectFolder

    ${NSD_GetState} $hCtlShortcuts $0
    ${If} $0 == ${BST_CHECKED}
        StrCpy $MakeShortcuts "1"
    ${Else}
        StrCpy $MakeShortcuts "0"
    ${EndIf}

    ${NSD_GetState} $hCtlFileAssoc $0
    ${If} $0 == ${BST_CHECKED}
        StrCpy $RegisterVgFiles "1"
    ${Else}
        StrCpy $RegisterVgFiles "0"
    ${EndIf}
FunctionEnd

; ── Custom page 2: AI keys (optional) ───────────────────────────────────
Function AIKeysPage
    !insertmacro MUI_HEADER_TEXT "AI Coding Assistant (optional)" \
        "Paste API keys now or leave blank — you can add them later from inside the IDE."

    nsDialogs::Create 1018
    Pop $0
    ${If} $0 == error
        Abort
    ${EndIf}

    ${NSD_CreateLabel} 0 0 100% 24u \
        "VisualGasic's built-in AI Coding Assistant works with OpenAI, Claude, Gemini, and Ollama. Leave any or all of these blank to skip."
    Pop $0

    ${NSD_CreateLabel} 0 30u 20% 12u "OpenAI:"
    Pop $0
    ${NSD_CreatePassword} 20% 30u 80% 12u "$OpenAIKey"
    Pop $hCtlOpenAI

    ${NSD_CreateLabel} 0 48u 20% 12u "Claude:"
    Pop $0
    ${NSD_CreatePassword} 20% 48u 80% 12u "$ClaudeKey"
    Pop $hCtlClaude

    ${NSD_CreateLabel} 0 66u 20% 12u "Gemini:"
    Pop $0
    ${NSD_CreatePassword} 20% 66u 80% 12u "$GeminiKey"
    Pop $hCtlGemini

    ${NSD_CreateLabel} 0 90u 100% 24u \
        "Ollama runs locally and needs no key — configure it from the IDE's AI Settings dialog after install."
    Pop $0

    nsDialogs::Show
FunctionEnd

Function AIKeysPageLeave
    ${NSD_GetText} $hCtlOpenAI $OpenAIKey
    ${NSD_GetText} $hCtlClaude $ClaudeKey
    ${NSD_GetText} $hCtlGemini $GeminiKey
FunctionEnd

; ── Install ──────────────────────────────────────────────────────────────
Section "VisualGasic first-time installer" SecMain
    SetOutPath "$INSTDIR"

    DetailPrint "Extracting installer payload..."
    File /r "${BUILD_DIR}\*.*"

    ; Build the bootstrap command line from the wizard values.
    ; $0 collects optional flags.
    StrCpy $0 ""
    ${If} $MakeShortcuts == "0"
        StrCpy $0 "$0 --no-launcher"
    ${EndIf}
    ${If} $RegisterVgFiles == "0"
        StrCpy $0 "$0 --no-file-assoc"
    ${EndIf}

    ; AI keys: only pass --with-ai-keys if at least one is provided.
    StrCpy $1 ""
    ${If} $OpenAIKey != ""
        StrCpy $1 "$1 --openai-key $\"$OpenAIKey$\""
    ${EndIf}
    ${If} $ClaudeKey != ""
        StrCpy $1 "$1 --claude-key $\"$ClaudeKey$\""
    ${EndIf}
    ${If} $GeminiKey != ""
        StrCpy $1 "$1 --gemini-key $\"$GeminiKey$\""
    ${EndIf}
    ${If} $1 != ""
        StrCpy $0 "$0 --with-ai-keys$1"
    ${EndIf}

    ; Small .cmd shim the user can re-run any time (uses defaults — for
    ; custom values they can re-run the .exe to get the wizard again).
    FileOpen $2 "$INSTDIR\run_installer.cmd" w
    FileWrite $2 "@echo off$\r$\n"
    FileWrite $2 "cd /d %~dp0$\r$\n"
    FileWrite $2 "set PYTHONUNBUFFERED=1$\r$\n"
    FileWrite $2 "set PYTHONIOENCODING=utf-8$\r$\n"
    FileWrite $2 "set SSL_CERT_FILE=%~dp0cacert.pem$\r$\n"
    FileWrite $2 "python\python.exe -X utf8 bootstrap_vg.py --offline %~dp0offline --launch %*$\r$\n"
    FileClose $2

    ; Run the first-time setup NOW with the wizard's values. We don't pass
    ; --launch here because subprocess.Popen from inside nsExec gets the
    ; child orphaned/killed when the installer wait completes; instead the
    ; MUI_FINISHPAGE_RUN checkbox launches the IDE via NSIS Exec, which is
    ; non-blocking and survives the installer process exiting.
    ;
    ; -X utf8 forces Python into UTF-8 mode so the embeddable runtime can
    ; print box-drawing / status icons without UnicodeEncodeError on the
    ; cp1252 console (which would otherwise abort the bootstrap as soon as
    ; download_with_progress emits its first progress line).
    ;
    ; PYTHONUNBUFFERED=1 makes nsExec see incremental output instead of a
    ; long silent block while Godot downloads.
    DetailPrint "Running first-time setup (this downloads Godot and can take a few minutes)..."
    nsExec::ExecToLog 'cmd.exe /c set PYTHONUNBUFFERED=1 && set PYTHONIOENCODING=utf-8 && set SSL_CERT_FILE=$INSTDIR\cacert.pem && "$INSTDIR\python\python.exe" -X utf8 "$INSTDIR\bootstrap_vg.py" --no-gui --offline "$INSTDIR\offline" --godot-version "$GodotVersion" --project-dir "$ProjectFolder" --display-name "$ProjectName" $0 > "$INSTDIR\install.log" 2>&1'
    Pop $3
    ${If} $3 != 0
        DetailPrint "First-time setup returned exit code $3."
        DetailPrint "Log saved to: $INSTDIR\install.log"
        DetailPrint "Re-run '$INSTDIR\run_installer.cmd' to retry, or share the log when filing an issue."
        MessageBox MB_ICONEXCLAMATION|MB_OK "VisualGasic first-time setup failed (exit code $3).$\r$\n$\r$\nA detailed log has been saved to:$\r$\n$INSTDIR\install.log$\r$\n$\r$\nPlease attach it when filing an issue at${APP_URL}/issues."
    ${Else}
        DetailPrint "Setup log: $INSTDIR\install.log"
    ${EndIf}

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

; ── Finish-page launch handler ────────────────────────────────────────
; Called by MUI_FINISHPAGE_RUN. Launches the VG IDE via the .cmd shim
; bootstrap_vg.py wrote to %LocalAppData%\VisualGasic\bin. NSIS Exec is
; non-blocking and the spawned process is independent of the installer,
; which avoids the orphan-on-exit problem that subprocess.Popen hits when
; called from inside nsExec.
Function LaunchVgIde
    StrCpy $0 "$LOCALAPPDATA\VisualGasic\bin\visualgasic-ide.cmd"
    IfFileExists "$0" 0 +3
        Exec '"$0"'
        Return
    DetailPrint "Launcher not found at $0 — open it from the Start Menu."
FunctionEnd

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
    Delete "$INSTDIR\bootstrap_gui.py"
    Delete "$INSTDIR\cacert.pem"
    Delete "$INSTDIR\install.log"
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
