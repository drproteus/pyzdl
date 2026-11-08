; Portable setup window for pyZDL. Mirrors installer/wizard.py and installer/install.py.
; It embeds build\pyZDL.exe, so build the launcher first (build.ps1 does this).

EnableExplicit

XIncludeFile "..\src\json.pbi"
XIncludeFile "..\src\core.pbi"
XIncludeFile "..\src\ini.pbi"
XIncludeFile "..\src\model.pbi"
XIncludeFile "..\src\ports.pbi"

Enumeration
  #Win_Setup
EndEnumeration

Enumeration 100
  #S_Heading
  #S_DirLabel
  #S_Dir
  #S_Browse
  #S_Scan
  #S_Shortcut
  #S_Launch
  #S_Status
  #S_Install
  #S_Cancel
EndEnumeration

DataSection
  PayloadStart:
  IncludeBinary "..\build\pyZDL.exe"
  PayloadEnd:
EndDataSection

Global HeadingFont.i

Procedure.s DefaultInstallDir()
  Define.s base$ = GetEnvironmentVariable("LOCALAPPDATA")
  If base$ = ""
    base$ = GetEnvironmentVariable("USERPROFILE")
  EndIf
  ProcedureReturn PathJoin(PathJoin(base$, "Programs"), "pyZDL")
EndProcedure

Procedure.b WriteEmbeddedExe(path$)
  Define.i file = CreateFile(#PB_Any, path$)
  If Not file
    ProcedureReturn #False
  EndIf
  WriteData(file, ?PayloadStart, ?PayloadEnd - ?PayloadStart)
  CloseFile(file)
  ProcedureReturn #True
EndProcedure

; The `gui` argument makes pyZDL skip the console, like the Python shortcut.
Procedure.b CreateShortcut(linkPath$, targetPath$)
  Define.s script$
  script$ = "$ws = New-Object -ComObject WScript.Shell; "
  script$ + "$link = $ws.CreateShortcut($env:PYZDL_LINK); "
  script$ + "$link.TargetPath = $env:PYZDL_TARGET; "
  script$ + "$link.Arguments = 'gui'; "
  script$ + "$link.WorkingDirectory = Split-Path -Parent $env:PYZDL_TARGET; "
  script$ + "$link.WindowStyle = 7; "
  script$ + "$link.IconLocation = $env:PYZDL_TARGET; "
  script$ + "$link.Save()"
  SetEnvironmentVariable("PYZDL_LINK", linkPath$)
  SetEnvironmentVariable("PYZDL_TARGET", targetPath$)
  RunProgram("powershell", "-NoProfile -ExecutionPolicy Bypass -Command " + CmdQuote(script$), "", #PB_Program_Wait | #PB_Program_Hide)
  ProcedureReturn Bool(IsFilePath(linkPath$))
EndProcedure

Global InstallMessage$

; Installs into installDir$. On failure the reason is left in LastError$, and on
; success the summary is left in InstallMessage$.
Procedure.b Install(installDir$, scan.b, shortcut.b, launch.b)
  Define.s exePath$, shortcutPath$, cfgFile$, desktopPath$, message$
  Define.i added = 0, configKept

  If Not EnsureDir(installDir$)
    ProcedureReturn Fail("Could not create " + installDir$)
  EndIf
  exePath$ = PathJoin(installDir$, "pyZDL.exe")
  If Not WriteEmbeddedExe(exePath$)
    ProcedureReturn Fail("Could not write " + exePath$)
  EndIf

  shortcutPath$ = PathJoin(installDir$, "pyZDL.lnk")
  If Not CreateShortcut(shortcutPath$, exePath$)
    ProcedureReturn Fail("Could not create the shortcut.")
  EndIf

  cfgFile$ = PathJoin(installDir$, "config.json")
  configKept = PathExists(cfgFile$)
  If scan And Not configKept
    DefaultScanRoots()
    ScanForPorts(3)
    added = AddFoundPortsToConfig(cfgFile$)
    If added < 0
      ProcedureReturn Fail("Could not update " + cfgFile$ + ": " + LastError$)
    EndIf
  EndIf

  If shortcut
    desktopPath$ = PathJoin(GetUserDirectory(#PB_Directory_Desktop), "pyZDL.lnk")
    CopyFile(shortcutPath$, desktopPath$)
  EndIf

  If launch
    RunProgram(exePath$, "gui", installDir$)
  EndIf

  message$ = "pyZDL was installed to:" + Chr(10) + Chr(10) + installDir$
  If configKept
    message$ + Chr(10) + Chr(10) + "An existing config.json was kept unchanged."
  ElseIf scan
    If added > 0
      message$ + Chr(10) + Chr(10) + "Source ports added to the config: " + Str(added)
    Else
      message$ + Chr(10) + Chr(10) + "Source ports added to the config: none"
    EndIf
  EndIf
  InstallMessage$ = message$
  ProcedureReturn #True
EndProcedure

; `pyZDL-setup.exe --install DIR [--no-scan] [--desktop] [--launch]` installs
; without a window, for scripting and testing.
Procedure.i SilentInstall()
  Define.i index, count = CountProgramParameters()
  Define.s dir$ = ""
  Define.b scan = #True, shortcut = #False, launch = #False
  For index = 0 To count - 1
    Select ProgramParameter(index)
      Case "--install"
        If index + 1 < count
          dir$ = ProgramParameter(index + 1)
        EndIf
      Case "--no-scan" : scan = #False
      Case "--desktop" : shortcut = #True
      Case "--launch" : launch = #True
    EndSelect
  Next
  If dir$ = ""
    OpenConsole()
    ConsoleError("Error: --install needs a folder.")
    ProcedureReturn 2
  EndIf
  If Not Install(AbsPath(dir$), scan, shortcut, launch)
    OpenConsole()
    ConsoleError("Error: Setup could not finish: " + LastError$)
    ProcedureReturn 1
  EndIf
  OpenConsole()
  PrintN(InstallMessage$)
  ProcedureReturn 0
EndProcedure

If CountProgramParameters() > 0
  End SilentInstall()
EndIf

If OpenWindow(#Win_Setup, 0, 0, 560, 380, "pyZDL Setup", #PB_Window_ScreenCentered | #PB_Window_SystemMenu | #PB_Window_MinimizeGadget)
  HeadingFont = LoadFont(#PB_Any, "Segoe UI", 15, #PB_Font_Bold)
  TextGadget(#S_Heading, 16, 16, 300, 30, "Install pyZDL")
  SetGadgetFont(#S_Heading, FontID(HeadingFont))
  TextGadget(#S_DirLabel, 16, 72, 110, 20, "Install folder:")
  StringGadget(#S_Dir, 130, 68, 310, 24, DefaultInstallDir())
  ButtonGadget(#S_Browse, 448, 68, 96, 24, "Browse...")
  CheckBoxGadget(#S_Scan, 16, 112, 520, 22, "Find installed source ports (GZDoom, Chocolate Doom, ...)")
  SetGadgetState(#S_Scan, #True)
  CheckBoxGadget(#S_Shortcut, 16, 142, 520, 22, "Add a desktop shortcut (opens the GUI)")
  SetGadgetState(#S_Shortcut, #True)
  CheckBoxGadget(#S_Launch, 16, 172, 520, 22, "Launch pyZDL when setup finishes")
  TextGadget(#S_Status, 16, 220, 528, 20, "")
  ButtonGadget(#S_Install, 360, 330, 90, 28, "Install")
  ButtonGadget(#S_Cancel, 456, 330, 90, 28, "Cancel")
  SetActiveGadget(#S_Install)

  Define.i event, quit = #False
  Define.s chosen$
  Repeat
    event = WaitWindowEvent()
    Select event
      Case #PB_Event_CloseWindow
        quit = #True
      Case #PB_Event_Gadget
        Select EventGadget()
          Case #S_Browse
            chosen$ = PathRequester("Choose the folder to install pyZDL into", GetGadgetText(#S_Dir))
            If chosen$ <> ""
              SetGadgetText(#S_Dir, chosen$)
            EndIf
          Case #S_Cancel
            quit = #True
          Case #S_Install
            chosen$ = Trim(GetGadgetText(#S_Dir))
            If chosen$ = ""
              MessageRequester("pyZDL Setup", "Choose an install folder.", #PB_MessageRequester_Warning)
            Else
              SetGadgetText(#S_Status, "Installing...")
              If Install(chosen$, GetGadgetState(#S_Scan), GetGadgetState(#S_Shortcut), GetGadgetState(#S_Launch))
                MessageRequester("pyZDL Setup", InstallMessage$, #PB_MessageRequester_Info)
                quit = #True
              Else
                SetGadgetText(#S_Status, "")
                MessageRequester("pyZDL Setup", "Setup could not finish:" + Chr(10) + Chr(10) + LastError$, #PB_MessageRequester_Error)
              EndIf
            EndIf
        EndSelect
    EndSelect
  Until quit
  CloseWindow(#Win_Setup)
EndIf
End 0
