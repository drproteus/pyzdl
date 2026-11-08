; Finds installed source ports in the usual Windows install locations. Mirrors
; lib/ports_scan.py.

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

; Common Windows install locations, including Scoop's user and global app folders.
Procedure DefaultScanRoots()
  Define.s user$ = GetEnvironmentVariable("USERPROFILE")
  Define.s scoop$ = GetEnvironmentVariable("SCOOP")
  Define.s scoopGlobal$ = GetEnvironmentVariable("SCOOP_GLOBAL")
  Define.s programData$ = GetEnvironmentVariable("ProgramData")
  ClearList(ScanRoots())
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
EndProcedure

; Scoop installs to apps\<app>\<version>\. Prefer apps\<app>\current\ so the path
; survives updates.
Procedure.s PreferScoopCurrent(path$)
  Define.s appDir$ = DirName(DirName(path$))
  Define.s candidate$
  If LCase(BaseName(DirName(appDir$))) <> "apps"
    ProcedureReturn path$
  EndIf
  candidate$ = PathJoin(PathJoin(appDir$, "current"), BaseName(path$))
  If IsFilePath(candidate$)
    ProcedureReturn candidate$
  EndIf
  ProcedureReturn path$
EndProcedure

Procedure ScanFolder(dir$, depth.i, maxDepth.i)
  Define.s name$, stem$, path$, portName$
  Define.i dirId, found
  NewList Subdirs.s()
  dirId = ExamineDirectory(#PB_Any, dir$, "*")
  If dirId = 0
    ProcedureReturn
  EndIf
  While NextDirectoryEntry(dirId)
    name$ = DirectoryEntryName(dirId)
    If DirectoryEntryType(dirId) = #PB_DirectoryEntry_Directory
      If name$ <> "." And name$ <> ".."
        LastElement(Subdirs()) : AddElement(Subdirs())
        Subdirs() = PathJoin(dir$, name$)
      EndIf
    ElseIf ExtLower(name$) = ".exe"
      stem$ = StemName(name$)
      portName$ = KnownPortName(stem$)
      If portName$ <> ""
        path$ = PreferScoopCurrent(PathJoin(dir$, name$))
        found = #False
        ForEach Found()
          If Found()\Name$ = portName$ Or LCase(Found()\Path$) = LCase(path$)
            found = #True
          EndIf
        Next
        If Not found
          LastElement(Found()) : AddElement(Found())
          Found()\Name$ = portName$
          Found()\Path$ = path$
        EndIf
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
