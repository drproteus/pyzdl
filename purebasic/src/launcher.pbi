; Builds the command for a profile and starts it. Mirrors lib/launcher.py: the
; same argument order, isolation rules, and error messages.

#PYZ_DETACHED_PROCESS = 8
#PYZ_FILE_APPEND_DATA = $4
#PYZ_GENERIC_READ = $80000000
#PYZ_SHARE_RW = 3
#PYZ_OPEN_ALWAYS = 4
#PYZ_OPEN_EXISTING = 3
#PYZ_FILE_ATTRIBUTE_NORMAL = $80
#PYZ_WAIT_OBJECT_0 = 0

; Explicit padding keeps the pointer field 8-byte aligned, matching SECURITY_ATTRIBUTES on x64.
Structure SecAttr
  nLength.l
  padding.l
  lpSecurityDescriptor.i
  bInheritHandle.l
  padding2.l
EndStructure

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

; Splits on spaces and tabs, keeping quoted text together. Quotes are removed from
; the ends of each token, like the Python version does on Windows.
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
; from a profile. Does not touch the filesystem beyond existence checks.
Procedure.b BuildLaunch(*p.Profile)
  Define.s exe$, iwad$, path$, config$, saves$, workdir$, rawPath$
  Define.i isolate, index, portPtr, iwadPtr

  ClearList(SpecArgs())
  portPtr = FindPortPtr(*p\PortName$)
  If portPtr = 0
    ProcedureReturn Fail("Unknown source port '" + *p\PortName$ + "'.")
  EndIf
  Define *port.NamedPath : *port = portPtr
  rawPath$ = *port\Path$
  exe$ = ExpandPath(rawPath$, PyzdlRoot$)
  If Not PathExists(exe$)
    ProcedureReturn Fail("Source port executable not found: " + rawPath$)
  EndIf

  iwadPtr = FindIwadPtr(*p\IwadName$)
  If iwadPtr = 0
    ProcedureReturn Fail("Unknown IWAD '" + *p\IwadName$ + "'.")
  EndIf
  Define *iwad.NamedPath : *iwad = iwadPtr
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
    Define *file.ProfileFile : *file = ProfileFilePtr(*p\ID, index)
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

Procedure.s CommandPreview()
  Define.s out$ = CmdQuote(SpecExe$)
  ForEach SpecArgs()
    out$ + " " + CmdQuote(SpecArgs())
  Next
  ProcedureReturn out$
EndProcedure

; Starts the game with stdout and stderr appended to the profile's launch.log.
; Returns the process handle, or 0 with LastError$ set.
Procedure.i StartGame(displayName$)
  Define.s cwd$ = "", wadPath$
  Define.i logHandle, nulHandle, ok, cwdPointer
  Define.SecAttr sa
  Define.STARTUPINFO si
  Define.PROCESS_INFORMATION pi
  Define.s cmd$

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

  sa\nLength = SizeOf(SecAttr)
  sa\lpSecurityDescriptor = 0
  sa\bInheritHandle = #True
  logHandle = CreateFile_(SpecLog$, #PYZ_FILE_APPEND_DATA, #PYZ_SHARE_RW, @sa, #PYZ_OPEN_ALWAYS, #PYZ_FILE_ATTRIBUTE_NORMAL, 0)
  nulHandle = CreateFile_("NUL", #PYZ_GENERIC_READ, #PYZ_SHARE_RW, @sa, #PYZ_OPEN_EXISTING, #PYZ_FILE_ATTRIBUTE_NORMAL, 0)
  If nulHandle = -1
    ProcedureReturn Fail("Could not open NUL for " + displayName$)
  EndIf
  If logHandle = -1
    logHandle = nulHandle
  EndIf

  SetEnvironmentVariable("DOOMWADDIR", DoomWadDir())
  wadPath$ = DoomWadPathValue()
  If wadPath$ <> ""
    SetEnvironmentVariable("DOOMWADPATH", wadPath$)
  EndIf

  si\cb = SizeOf(STARTUPINFO)
  si\dwFlags = #STARTF_USESTDHANDLES
  si\hStdInput = nulHandle
  si\hStdOutput = logHandle
  si\hStdError = logHandle

  cmd$ = CommandPreview()
  cwdPointer = 0
  If cwd$ <> ""
    cwdPointer = @cwd$
  EndIf
  ok = CreateProcess_(0, @cmd$, 0, 0, #True, 0, 0, cwdPointer, @si, @pi)

  If logHandle <> nulHandle
    CloseHandle_(logHandle)
  EndIf
  CloseHandle_(nulHandle)

  If Not ok
    ProcedureReturn Fail("Could not start " + SpecExe$ + " (error " + Str(GetLastError_()) + ")")
  EndIf
  CloseHandle_(pi\hThread)
  ProcedureReturn pi\hProcess
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
    If WaitForSingleObject_(Running()\Handle, 0) = #PYZ_WAIT_OBJECT_0
      GetExitCodeProcess_(Running()\Handle, @FinishedCode)
      CloseHandle_(Running()\Handle)
      FinishedName$ = Running()\Name$
      DeleteElement(Running())
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure
