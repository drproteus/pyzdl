; Builds the command for a profile and starts it. Mirrors lib/launcher.py: the
; same argument order, isolation rules, and error messages.

Structure RunningGame
  Name$
  Handle.i
EndStructure

Global NewList SpecArgs.s()
Global NewList ExtraArgs.s()
Global NewList SplitOut.s()
Global NewList Running.RunningGame()

Global SpecExe$
Global SpecCwd$
Global SpecConfig$
Global SpecSaves$
Global SpecLog$
Global FinishedName$
Global FinishedCode.l

Procedure.s StripQuotes(token$)
  If Len(token$) >= 2
    If Left(token$, 1) = Right(token$, 1) And (Left(token$, 1) = Chr(34) Or Left(token$, 1) = "'")
      ProcedureReturn Mid(token$, 2, Len(token$) - 2)
    EndIf
  EndIf
  ProcedureReturn token$
EndProcedure

; Splits on whitespace, keeping quoted text together. Quotes are removed from the
; ends of each token, like the Python version does on Windows.
Procedure.b SplitArgs(text$)
  Define.s token$ = "", c$
  Define.i i, quote = 0, inToken = #False
  ClearList(SplitOut())
  For i = 1 To Len(text$)
    c$ = Mid(text$, i, 1)
    If quote = 0
      If c$ = " " Or c$ = Chr(9) Or c$ = Chr(10) Or c$ = Chr(13)
        If inToken
          LastElement(SplitOut()) : AddElement(SplitOut())
          SplitOut() = StripQuotes(token$)
          token$ = ""
          inToken = #False
        EndIf
      Else
        inToken = #True
        token$ + c$
        If c$ = Chr(34) Or c$ = "'"
          quote = Asc(c$)
        EndIf
      EndIf
    Else
      token$ + c$
      If Asc(c$) = quote
        quote = 0
      EndIf
    EndIf
  Next
  If quote <> 0
    ProcedureReturn Fail("Could not parse extra arguments: No closing quotation")
  EndIf
  If inToken
    LastElement(SplitOut()) : AddElement(SplitOut())
    SplitOut() = StripQuotes(token$)
  EndIf
  ProcedureReturn #True
EndProcedure

Procedure.b HasGameFlag(flag$)
  ForEach SpecArgs()
    If SpecArgs() = flag$ Or Left(SpecArgs(), Len(flag$) + 1) = flag$ + "="
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure.s FileFlag(path$)
  Define.s ext$ = ExtLower(path$)
  If ext$ = ".deh" Or ext$ = ".bex"
    ProcedureReturn "-deh"
  EndIf
  ProcedureReturn "-file"
EndProcedure

; Fills SpecExe$, SpecCwd$, SpecConfig$, SpecSaves$, SpecLog$, and SpecArgs()
; from a profile. Only checks that paths exist; nothing is created.
Procedure.b BuildLaunch(*p.Profile)
  Define.s exe$, iwad$, path$, config$, saves$, workdir$, rawPath$
  Define.i isolate, index, portPtr, iwadPtr

  ClearList(SpecArgs())
  portPtr = FindPortPtr(*p\PortName$)
  If portPtr = 0
    ProcedureReturn Fail("Unknown source port '" + *p\PortName$ + "'.")
  EndIf
  Define *port.NamedPath = portPtr
  rawPath$ = *port\Path$
  exe$ = ExpandPath(rawPath$, PyzdlRoot$)
  If Not PathExists(exe$)
    ProcedureReturn Fail("Source port executable not found: " + rawPath$)
  EndIf

  iwadPtr = FindIwadPtr(*p\IwadName$)
  If iwadPtr = 0
    ProcedureReturn Fail("Unknown IWAD '" + *p\IwadName$ + "'.")
  EndIf
  Define *iwad.NamedPath = iwadPtr
  rawPath$ = *iwad\Path$
  iwad$ = ExpandPath(rawPath$, PyzdlRoot$)
  If Not IsFilePath(iwad$)
    ProcedureReturn Fail("IWAD not found: " + rawPath$)
  EndIf
  LastElement(SpecArgs()) : AddElement(SpecArgs())
  SpecArgs() = "-iwad"
  LastElement(SpecArgs()) : AddElement(SpecArgs())
  SpecArgs() = iwad$

  For index = 0 To ProfileFileCount(*p\ID) - 1
    Define *file.ProfileFile = ProfileFilePtr(*p\ID, index)
    If *file\Enabled
      rawPath$ = *file\Path$
      path$ = ExpandPath(rawPath$, PyzdlRoot$)
      If Not PathExists(path$)
        ProcedureReturn Fail("Mod file not found: " + rawPath$)
      EndIf
      LastElement(SpecArgs()) : AddElement(SpecArgs())
      SpecArgs() = FileFlag(path$)
      LastElement(SpecArgs()) : AddElement(SpecArgs())
      SpecArgs() = path$
    EndIf
  Next

  If Not SplitArgs(*p\Args$)
    ProcedureReturn #False
  EndIf
  ForEach SplitOut()
    LastElement(SpecArgs()) : AddElement(SpecArgs())
    SpecArgs() = SplitOut()
  Next
  ForEach ExtraArgs()
    LastElement(SpecArgs()) : AddElement(SpecArgs())
    SpecArgs() = ExtraArgs()
  Next

  If *p\IsolateConfig = #Tri_Default
    isolate = SettingProfileConfigs
  Else
    isolate = *p\IsolateConfig
  EndIf
  config$ = ExpandPath(*p\CfgPath$, PyzdlRoot$)
  If config$ = "" And isolate
    config$ = ProfileDefaultConfig(*p)
  EndIf
  If HasGameFlag("-config")
    config$ = ""
  ElseIf config$ <> ""
    If PathExists(config$) And Not IsFilePath(config$)
      ProcedureReturn Fail("Config path is not a file: " + config$)
    EndIf
    LastElement(SpecArgs()) : AddElement(SpecArgs())
    SpecArgs() = "-config"
    LastElement(SpecArgs()) : AddElement(SpecArgs())
    SpecArgs() = config$
  EndIf

  If *p\IsolateSaves = #Tri_Default
    isolate = SettingProfileSaves
  Else
    isolate = *p\IsolateSaves
  EndIf
  saves$ = ExpandPath(*p\SavePath$, PyzdlRoot$)
  If saves$ = "" And isolate
    saves$ = ProfileSavePath(*p)
  EndIf
  If HasGameFlag("-savedir")
    saves$ = ""
  ElseIf saves$ <> ""
    If PathExists(saves$) And Not IsDirPath(saves$)
      ProcedureReturn Fail("Save path is not a directory: " + saves$)
    EndIf
    LastElement(SpecArgs()) : AddElement(SpecArgs())
    SpecArgs() = "-savedir"
    LastElement(SpecArgs()) : AddElement(SpecArgs())
    SpecArgs() = saves$
  EndIf

  workdir$ = ExpandPath(*p\WorkDir$, PyzdlRoot$)
  If workdir$ = "" And IsFilePath(exe$)
    workdir$ = DirName(exe$)
  EndIf

  SpecExe$ = exe$
  SpecCwd$ = workdir$
  SpecConfig$ = config$
  SpecSaves$ = saves$
  SpecLog$ = PathJoin(ProfileDirPath(*p), "launch.log")
  ProcedureReturn #True
EndProcedure

; A macOS .app bundle is started with `open`, passing game arguments after --args.
Procedure.b IsMacAppBundle(path$)
  If Not #PYZ_IS_MACOS
    ProcedureReturn #False
  EndIf
  ProcedureReturn Bool(ExtLower(path$) = ".app" And IsDirPath(path$))
EndProcedure

Procedure.s GameCommand()
  Define.s args$ = ""
  ForEach SpecArgs()
    args$ + " " + ArgQuote(SpecArgs())
  Next
  If IsMacAppBundle(SpecExe$)
    If ListSize(SpecArgs()) > 0
      ProcedureReturn "open " + ArgQuote(SpecExe$) + " --args" + args$
    EndIf
    ProcedureReturn "open " + ArgQuote(SpecExe$)
  EndIf
  ProcedureReturn ArgQuote(SpecExe$) + args$
EndProcedure

Procedure.s CommandPreview()
  ProcedureReturn GameCommand()
EndProcedure

; Starts the game with stdout and stderr appended to the profile's launch.log.
; Returns a handle for ReapGame, or 0 with LastError$ set.
Procedure.i StartGame(displayName$)
  Define.s cwd$ = "", wadPath$
  If SpecConfig$ <> ""
    EnsureDir(DirName(SpecConfig$))
  EndIf
  If SpecSaves$ <> ""
    EnsureDir(SpecSaves$)
  EndIf
  If IsDirPath(SpecCwd$)
    cwd$ = SpecCwd$
  EndIf
  EnsureDir(DirName(SpecLog$))

  SetEnvironmentVariable("DOOMWADDIR", DoomWadDir())
  wadPath$ = DoomWadPathValue()
  If wadPath$ <> ""
    SetEnvironmentVariable("DOOMWADPATH", ReplaceString(wadPath$, ";", #PYZ_PATHLIST$))
  EndIf

  ProcedureReturn PlatformStartProcess(GameCommand(), cwd$, SpecLog$)
EndProcedure

Procedure.i LaunchProfile(*p.Profile)
  Define.s defaults$
  Define.i handle
  If Not BuildLaunch(*p)
    ProcedureReturn 0
  EndIf
  If SpecConfig$ <> "" And Not PathExists(SpecConfig$)
    defaults$ = DefaultGzConfig()
    If IsFilePath(defaults$)
      EnsureDir(DirName(SpecConfig$))
      CopyFile(defaults$, SpecConfig$)
    EndIf
  EndIf
  handle = StartGame(*p\Name$)
  If handle
    LastElement(Running()) : AddElement(Running())
    Running()\Name$ = *p\Name$
    Running()\Handle = handle
  EndIf
  ProcedureReturn handle
EndProcedure

; Reports the next game that has exited through FinishedName$ and FinishedCode.
; Returns #True once per exit.
Procedure.b ReapGame()
  ForEach Running()
    If TryReapGame(Running()\Handle, @FinishedCode)
      FinishedName$ = Running()\Name$
      DeleteElement(Running())
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure
