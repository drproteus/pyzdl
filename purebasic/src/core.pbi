; Shared helpers: paths, file I/O, and error reporting.

Global LastError$

Procedure.b Fail(message$)
  LastError$ = message$
  ProcedureReturn #False
EndProcedure

Procedure.s Backslashes(count.i)
  ProcedureReturn ReplaceString(Space(count), " ", "\")
EndProcedure

Procedure.s PathJoin(a$, b$)
  If a$ = ""
    ProcedureReturn b$
  EndIf
  If b$ = ""
    ProcedureReturn a$
  EndIf
  If Right(a$, 1) = "\" Or Right(a$, 1) = "/"
    ProcedureReturn a$ + b$
  EndIf
  ProcedureReturn a$ + "\" + b$
EndProcedure

Procedure.b IsAbsPath(path$)
  If Len(path$) >= 2 And Mid(path$, 2, 1) = ":"
    ProcedureReturn #True
  EndIf
  If Left(path$, 1) = "\" Or Left(path$, 1) = "/"
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

; Expands %NAME% references. Unknown names are left as written, like os.path.expandvars.
Procedure.s ExpandVars(text$)
  Define.s out$ = "", name$, value$
  Define.i start = 1, openPos, closePos
  While start <= Len(text$)
    openPos = FindString(text$, "%", start)
    If openPos = 0
      Break
    EndIf
    closePos = FindString(text$, "%", openPos + 1)
    If closePos = 0
      Break
    EndIf
    name$ = Mid(text$, openPos + 1, closePos - openPos - 1)
    value$ = ""
    If name$ <> ""
      value$ = GetEnvironmentVariable(name$)
    EndIf
    out$ + Mid(text$, start, openPos - start)
    If value$ <> ""
      out$ + value$
    Else
      out$ + Mid(text$, openPos, closePos - openPos + 1)
    EndIf
    start = closePos + 1
  Wend
  ProcedureReturn out$ + Mid(text$, start)
EndProcedure

Procedure.s ExpandUser(text$)
  Define.s next$
  If Left(text$, 1) = "~"
    next$ = Mid(text$, 2, 1)
    If next$ = "" Or next$ = "\" Or next$ = "/"
      ProcedureReturn GetEnvironmentVariable("USERPROFILE") + Mid(text$, 2)
    EndIf
  EndIf
  ProcedureReturn text$
EndProcedure

; Collapses "." and ".." segments and converts "/" to "\".
Procedure.s NormPath(path$)
  NewList NormParts.s()
  Define.s prefix$ = "", rest$, part$, out$ = ""
  Define.i i, count, rooted
  path$ = ReplaceString(path$, "/", "\")
  If Len(path$) >= 2 And Mid(path$, 2, 1) = ":"
    prefix$ = Left(path$, 2)
    rest$ = Mid(path$, 3)
  ElseIf Left(path$, 2) = "\\"
    prefix$ = "\\"
    rest$ = Mid(path$, 3)
  Else
    rest$ = path$
  EndIf
  rooted = Bool(Left(rest$, 1) = "\")
  count = CountString(rest$, "\") + 1
  For i = 1 To count
    part$ = StringField(rest$, i, "\")
    If part$ = "" Or part$ = "."
      Continue
    ElseIf part$ = ".."
      If ListSize(NormParts()) > 0 And LastElement(NormParts()) And NormParts() <> ".."
        DeleteElement(NormParts())
      ElseIf Not rooted
        LastElement(NormParts()) : AddElement(NormParts())
        NormParts() = ".."
      EndIf
    Else
      LastElement(NormParts()) : AddElement(NormParts())
      NormParts() = part$
    EndIf
  Next
  ForEach NormParts()
    If out$ <> ""
      out$ + "\"
    EndIf
    out$ + NormParts()
  Next
  If rooted
    ProcedureReturn prefix$ + "\" + out$
  EndIf
  If out$ = ""
    ProcedureReturn prefix$ + "."
  EndIf
  ProcedureReturn prefix$ + out$
EndProcedure

; Equivalent of lib.config.expand_path: ~, %VAR%, and relative paths against base.
Procedure.s ExpandPath(path$, base$ = "")
  Define.s value$
  If path$ = ""
    ProcedureReturn ""
  EndIf
  value$ = ExpandVars(ExpandUser(path$))
  If base$ <> "" And Not IsAbsPath(value$)
    value$ = PathJoin(base$, value$)
  EndIf
  ProcedureReturn NormPath(value$)
EndProcedure

Procedure.s AbsPath(path$)
  ProcedureReturn ExpandPath(path$, GetCurrentDirectory())
EndProcedure

Procedure.s DirName(path$)
  Define.s p$ = ReplaceString(path$, "/", "\")
  Define.i i
  For i = Len(p$) To 1 Step -1
    If Mid(p$, i, 1) = "\"
      If i = 1
        ProcedureReturn "\"
      EndIf
      If i = 3 And Mid(p$, 2, 1) = ":"
        ProcedureReturn Left(p$, 3)
      EndIf
      ProcedureReturn Left(p$, i - 1)
    EndIf
  Next
  ProcedureReturn ""
EndProcedure

Procedure.s BaseName(path$)
  Define.s p$ = ReplaceString(path$, "/", "\")
  Define.i i
  For i = Len(p$) To 1 Step -1
    If Mid(p$, i, 1) = "\"
      ProcedureReturn Mid(p$, i + 1)
    EndIf
  Next
  ProcedureReturn p$
EndProcedure

; Lower-case extension including the dot, or "" when there is none.
Procedure.s ExtLower(path$)
  Define.s name$ = BaseName(path$)
  Define.i i
  For i = Len(name$) To 1 Step -1
    If Mid(name$, i, 1) = "."
      ProcedureReturn LCase(Mid(name$, i))
    EndIf
  Next
  ProcedureReturn ""
EndProcedure

Procedure.s StemName(path$)
  Define.s name$ = BaseName(path$)
  Define.i i
  For i = Len(name$) To 1 Step -1
    If Mid(name$, i, 1) = "."
      ProcedureReturn Left(name$, i - 1)
    EndIf
  Next
  ProcedureReturn name$
EndProcedure

Procedure.b PathExists(path$)
  If path$ = ""
    ProcedureReturn #False
  EndIf
  ProcedureReturn Bool(FileSize(path$) <> -1)
EndProcedure

Procedure.b IsFilePath(path$)
  If path$ = ""
    ProcedureReturn #False
  EndIf
  ProcedureReturn Bool(FileSize(path$) >= 0)
EndProcedure

Procedure.b IsDirPath(path$)
  If path$ = ""
    ProcedureReturn #False
  EndIf
  ProcedureReturn Bool(FileSize(path$) = -2)
EndProcedure

Procedure.b EnsureDir(path$)
  Define.s parent$
  If path$ = "" Or IsDirPath(path$)
    ProcedureReturn #True
  EndIf
  parent$ = DirName(path$)
  If parent$ <> "" And parent$ <> path$
    EnsureDir(parent$)
  EndIf
  ProcedureReturn Bool(CreateDirectory(path$))
EndProcedure

Procedure.s ReadTextFile(path$)
  Define.s text$ = ""
  Define.i file, size
  Define *buffer
  If Not IsFilePath(path$)
    ProcedureReturn ""
  EndIf
  file = ReadFile(#PB_Any, path$)
  If file
    size = Lof(file)
    If size > 0
      *buffer = AllocateMemory(size)
      ReadData(file, *buffer, size)
      text$ = PeekS(*buffer, size, #PB_UTF8)
      FreeMemory(*buffer)
    EndIf
    CloseFile(file)
  EndIf
  ProcedureReturn text$
EndProcedure

; Writes UTF-8 without a byte-order mark, which Python's json module rejects.
Procedure.b WriteTextFile(path$, text$)
  Define.i file, size
  Define *buffer
  If Not EnsureDir(DirName(path$))
    ProcedureReturn Fail("Could not create folder for " + path$)
  EndIf
  file = CreateFile(#PB_Any, path$)
  If Not file
    ProcedureReturn Fail("Could not write " + path$)
  EndIf
  size = StringByteLength(text$, #PB_UTF8)
  *buffer = AllocateMemory(size + 2)
  PokeS(*buffer, text$, -1, #PB_UTF8)
  WriteData(file, *buffer, size)
  CloseFile(file)
  FreeMemory(*buffer)
  ProcedureReturn #True
EndProcedure

; Writes a sibling temp file, then swaps it into place so a crash cannot leave
; a truncated config behind.
Procedure.b WriteTextFileAtomic(path$, text$)
  Define.s temp$ = PathJoin(DirName(path$), ".pyzdl-" + Str(Random(999999999)) + ".tmp")
  If Not WriteTextFile(temp$, text$)
    ProcedureReturn #False
  EndIf
  If IsFilePath(path$)
    DeleteFile(path$)
  EndIf
  If Not RenameFile(temp$, path$)
    DeleteFile(temp$)
    ProcedureReturn Fail("Could not replace " + path$)
  EndIf
  ProcedureReturn #True
EndProcedure

; Quotes one argument for a Windows command line, like subprocess.list2cmdline.
Procedure.s CmdQuote(arg$)
  Define.s out$, c$
  Define.i i, slashes = 0
  If arg$ = ""
    ProcedureReturn Chr(34) + Chr(34)
  EndIf
  If FindString(arg$, " ") = 0 And FindString(arg$, Chr(9)) = 0 And FindString(arg$, Chr(34)) = 0
    ProcedureReturn arg$
  EndIf
  out$ = Chr(34)
  For i = 1 To Len(arg$)
    c$ = Mid(arg$, i, 1)
    If c$ = "\"
      slashes + 1
    ElseIf c$ = Chr(34)
      out$ + Backslashes(slashes * 2 + 1) + Chr(34)
      slashes = 0
    Else
      out$ + Backslashes(slashes) + c$
      slashes = 0
    EndIf
  Next
  out$ + Backslashes(slashes * 2) + Chr(34)
  ProcedureReturn out$
EndProcedure

Procedure.s ExeDir()
  ProcedureReturn DirName(ProgramFilename())
EndProcedure
