; Shared helpers: paths, file I/O, and error reporting. Paths use the native
; separator (#PS$). On Windows, "/" is also accepted and converted.

Global LastError$

Procedure.b Fail(message$)
  LastError$ = message$
  ProcedureReturn #False
EndProcedure

Procedure.s NativePath(path$)
  If #PYZ_IS_WINDOWS
    ProcedureReturn ReplaceString(path$, "/", "\")
  EndIf
  ProcedureReturn path$
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
  ProcedureReturn a$ + #PS$ + b$
EndProcedure

Procedure.b IsAbsPath(path$)
  path$ = NativePath(path$)
  If #PYZ_IS_WINDOWS
    If Len(path$) >= 2 And Mid(path$, 2, 1) = ":"
      ProcedureReturn #True
    EndIf
  EndIf
  If Left(path$, 1) = #PS$
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

; Windows: expands %NAME%. Other platforms: expands $NAME and ${NAME}. Unknown
; names are left as written, like os.path.expandvars.
Procedure.s ExpandVars(text$)
  Define.s out$ = "", name$, value$, c$
  Define.i i = 1, closePos
  If #PYZ_IS_WINDOWS
    Define.i openPos
    While i <= Len(text$)
      openPos = FindString(text$, "%", i)
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
      out$ + Mid(text$, i, openPos - i)
      If value$ <> ""
        out$ + value$
      Else
        out$ + Mid(text$, openPos, closePos - openPos + 1)
      EndIf
      i = closePos + 1
    Wend
    ProcedureReturn out$ + Mid(text$, i)
  EndIf

  While i <= Len(text$)
    c$ = Mid(text$, i, 1)
    If c$ <> "$"
      out$ + c$
      i + 1
      Continue
    EndIf
    name$ = ""
    If Mid(text$, i + 1, 1) = "{"
      closePos = FindString(text$, "}", i + 2)
      If closePos = 0
        out$ + c$
        i + 1
        Continue
      EndIf
      name$ = Mid(text$, i + 2, closePos - i - 2)
      i = closePos + 1
    Else
      closePos = i + 1
      While closePos <= Len(text$) And FindString("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_", Mid(text$, closePos, 1), 1)
        closePos + 1
      Wend
      name$ = Mid(text$, i + 1, closePos - i - 1)
      i = closePos
    EndIf
    value$ = ""
    If name$ <> ""
      value$ = GetEnvironmentVariable(name$)
    EndIf
    If value$ <> ""
      out$ + value$
    ElseIf name$ <> ""
      out$ + "$" + name$
    Else
      out$ + "$"
    EndIf
  Wend
  ProcedureReturn out$
EndProcedure

Procedure.s ExpandUser(text$)
  Define.s home$, next$
  If Left(text$, 1) = "~"
    next$ = Mid(text$, 2, 1)
    If next$ = "" Or next$ = "\" Or next$ = "/"
      home$ = GetHomeDirectory()
      If Right(home$, 1) = "\" Or Right(home$, 1) = "/"
        home$ = Left(home$, Len(home$) - 1)
      EndIf
      ProcedureReturn home$ + Mid(text$, 2)
    EndIf
  EndIf
  ProcedureReturn text$
EndProcedure

; Collapses "." and ".." segments. Keeps a Windows drive or UNC prefix.
Procedure.s NormPath(path$)
  NewList NormParts.s()
  Define.s prefix$ = "", rest$, part$, out$ = ""
  Define.i i, count, rooted
  path$ = NativePath(path$)
  rest$ = path$
  If #PYZ_IS_WINDOWS
    If Len(path$) >= 2 And Mid(path$, 2, 1) = ":"
      prefix$ = Left(path$, 2)
      rest$ = Mid(path$, 3)
    ElseIf Left(path$, 2) = "\\"
      prefix$ = "\\"
      rest$ = Mid(path$, 3)
    EndIf
  EndIf
  rooted = Bool(Left(rest$, 1) = #PS$)
  count = CountString(rest$, #PS$) + 1
  For i = 1 To count
    part$ = StringField(rest$, i, #PS$)
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
      out$ + #PS$
    EndIf
    out$ + NormParts()
  Next
  If rooted
    ProcedureReturn prefix$ + #PS$ + out$
  EndIf
  If out$ = ""
    ProcedureReturn prefix$ + "."
  EndIf
  ProcedureReturn prefix$ + out$
EndProcedure

; Equivalent of lib.config.expand_path: ~, environment variables, and relative
; paths resolved against base.
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
  Define.s p$ = NativePath(path$)
  Define.i i
  For i = Len(p$) To 1 Step -1
    If Mid(p$, i, 1) = #PS$
      If i = 1
        ProcedureReturn #PS$
      EndIf
      If #PYZ_IS_WINDOWS And i = 3 And Mid(p$, 2, 1) = ":"
        ProcedureReturn Left(p$, 3)
      EndIf
      ProcedureReturn Left(p$, i - 1)
    EndIf
  Next
  ProcedureReturn ""
EndProcedure

Procedure.s BaseName(path$)
  Define.s p$ = NativePath(path$)
  Define.i i
  For i = Len(p$) To 1 Step -1
    If Mid(p$, i, 1) = #PS$
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

Procedure.s ExeDir()
  ProcedureReturn DirName(ProgramFilename())
EndProcedure
