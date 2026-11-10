; Finds installed source ports in the usual install locations for the current OS.
; Mirrors lib/ports_scan.py for Windows and extends it to macOS and Linux.

Structure FoundPort
  Name$
  Path$
EndStructure

Global NewList Found.FoundPort()
Global NewList ScanRoots.s()

Procedure.s KnownPortName(stem$)
  Select LCase(stem$)
    Case "gzdoom" : ProcedureReturn "GZDoom"
    Case "lzdoom" : ProcedureReturn "LZDoom"
    Case "zdoom" : ProcedureReturn "ZDoom"
    Case "qzdoom" : ProcedureReturn "QZDoom"
    Case "uzdoom" : ProcedureReturn "UZDoom"
    Case "chocolate-doom" : ProcedureReturn "Chocolate Doom"
    Case "crispy-doom" : ProcedureReturn "Crispy Doom"
    Case "dsda-doom" : ProcedureReturn "DSDA-Doom"
    Case "woof" : ProcedureReturn "Woof"
    Case "prboom-plus" : ProcedureReturn "PrBoom-Plus"
    Case "eternity" : ProcedureReturn "Eternity"
  EndSelect
  ProcedureReturn ""
EndProcedure

; The port name for a directory entry, or "" when it is not a known port.
; Windows: NAME.exe. macOS: NAME.app bundles. Linux: an extensionless executable.
Procedure.s MatchPortName(name$, isDirectory.b)
  If isDirectory
    If #PYZ_IS_MACOS And ExtLower(name$) = ".app"
      ProcedureReturn KnownPortName(StemName(name$))
    EndIf
    ProcedureReturn ""
  EndIf
  If #PYZ_IS_WINDOWS
    If ExtLower(name$) = ".exe"
      ProcedureReturn KnownPortName(StemName(name$))
    EndIf
    ProcedureReturn ""
  EndIf
  ProcedureReturn KnownPortName(name$)
EndProcedure

Procedure.b AddScanRoot(path$)
  Define.s key$ = LCase(path$)
  If Not IsDirPath(path$)
    ProcedureReturn #False
  EndIf
  ForEach ScanRoots()
    If LCase(ScanRoots()) = key$
      ProcedureReturn #False
    EndIf
  Next
  LastElement(ScanRoots()) : AddElement(ScanRoots())
  ScanRoots() = path$
  ProcedureReturn #True
EndProcedure

; Windows: LOCALAPPDATA, APPDATA, Program Files, and the Scoop app folders.
; macOS: Applications and ~/Games. Linux: the usual games and /opt locations.
Procedure DefaultScanRoots()
  Define.s home$ = GetHomeDirectory()
  ClearList(ScanRoots())
  If #PYZ_IS_WINDOWS
    Define.s user$ = GetEnvironmentVariable("USERPROFILE")
    Define.s scoop$ = GetEnvironmentVariable("SCOOP")
    Define.s scoopGlobal$ = GetEnvironmentVariable("SCOOP_GLOBAL")
    Define.s programData$ = GetEnvironmentVariable("ProgramData")
    AddScanRoot(GetEnvironmentVariable("LOCALAPPDATA"))
    AddScanRoot(GetEnvironmentVariable("APPDATA"))
    AddScanRoot(GetEnvironmentVariable("PROGRAMFILES"))
    AddScanRoot(GetEnvironmentVariable("PROGRAMFILES(X86)"))
    AddScanRoot(GetEnvironmentVariable("PROGRAMW6432"))
    If scoop$ = ""
      scoop$ = PathJoin(user$, "scoop")
    EndIf
    AddScanRoot(PathJoin(scoop$, "apps"))
    If scoopGlobal$ = ""
      If programData$ = ""
        programData$ = "C:\ProgramData"
      EndIf
      scoopGlobal$ = PathJoin(programData$, "scoop")
    EndIf
    AddScanRoot(PathJoin(scoopGlobal$, "apps"))
  Else
    If #PYZ_IS_MACOS
      AddScanRoot("/Applications")
      AddScanRoot(PathJoin(home$, "Applications"))
    EndIf
    AddScanRoot(PathJoin(home$, "Games"))
    AddScanRoot("/usr/games")
    AddScanRoot("/usr/local/games")
    AddScanRoot("/opt")
  EndIf
EndProcedure

; Scoop installs to apps\<app>\<version>\. Prefer apps\<app>\current\ so the path
; survives updates.
Procedure.s PreferScoopCurrent(path$)
  Define.s appDir$ = DirName(DirName(path$))
  Define.s candidate$
  If Not #PYZ_IS_WINDOWS
    ProcedureReturn path$
  EndIf
  If LCase(BaseName(DirName(appDir$))) <> "apps"
    ProcedureReturn path$
  EndIf
  candidate$ = PathJoin(PathJoin(appDir$, "current"), BaseName(path$))
  If IsFilePath(candidate$)
    ProcedureReturn candidate$
  EndIf
  ProcedureReturn path$
EndProcedure

Procedure AddFoundPort(name$, path$)
  Define.b found = #False
  ForEach Found()
    If Found()\Name$ = name$ Or LCase(Found()\Path$) = LCase(path$)
      found = #True
    EndIf
  Next
  If Not found
    LastElement(Found()) : AddElement(Found())
    Found()\Name$ = name$
    Found()\Path$ = path$
  EndIf
EndProcedure

Procedure ScanFolder(dir$, depth.i, maxDepth.i)
  Define.s name$, portName$, path$
  Define.i dirId
  Define.b isDirectory
  NewList Subdirs.s()
  dirId = ExamineDirectory(#PB_Any, dir$, "*")
  If dirId = 0
    ProcedureReturn
  EndIf
  While NextDirectoryEntry(dirId)
    name$ = DirectoryEntryName(dirId)
    isDirectory = Bool(DirectoryEntryType(dirId) = #PB_DirectoryEntry_Directory)
    If isDirectory And (name$ = "." Or name$ = "..")
      Continue
    EndIf
    portName$ = MatchPortName(name$, isDirectory)
    If portName$ <> ""
      path$ = PreferScoopCurrent(PathJoin(dir$, name$))
      AddFoundPort(portName$, path$)
    ElseIf isDirectory
      ; A macOS app bundle is a folder, but it is never searched inside.
      If Not (#PYZ_IS_MACOS And ExtLower(name$) = ".app")
        LastElement(Subdirs()) : AddElement(Subdirs())
        Subdirs() = PathJoin(dir$, name$)
      EndIf
    EndIf
  Wend
  FinishDirectory(dirId)
  If depth < maxDepth
    ForEach Subdirs()
      ScanFolder(Subdirs(), depth + 1, maxDepth)
    Next
  EndIf
EndProcedure

; Scans every root in ScanRoots() and fills Found(). Folders deeper than maxDepth
; are not entered.
Procedure ScanForPorts(maxDepth.i = 3)
  ClearList(Found())
  ForEach ScanRoots()
    ScanFolder(ScanRoots(), 0, maxDepth)
  Next
EndProcedure

; Adds ports the config does not list yet. Returns the number added, or -1 on error.
Procedure.i AddFoundPortsToConfig(configPath$)
  Define.i added = 0
  If Not LoadConfig(configPath$)
    ProcedureReturn -1
  EndIf
  ForEach Found()
    If FindPortPtr(Found()\Name$) = 0
      If AddPortEntry(Found()\Name$, Found()\Path$)
        added + 1
      EndIf
    EndIf
  Next
  If added > 0 And Not WriteConfig()
    ProcedureReturn -1
  EndIf
  ProcedureReturn added
EndProcedure
