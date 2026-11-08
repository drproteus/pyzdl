; Minimal INI reader for ZDL files. Keys are lower-cased and sections keep their
; order, matching Python's configparser defaults used by the original launcher.

Structure IniEntry
  Section$
  Key$
  Value$
EndStructure

Global NewList IniEntries.IniEntry()

Procedure.b IsDigitsOnly(text$)
  Define.i i
  If text$ = ""
    ProcedureReturn #False
  EndIf
  For i = 1 To Len(text$)
    If FindString("0123456789", Mid(text$, i, 1), 1) = 0
      ProcedureReturn #False
    EndIf
  Next
  ProcedureReturn #True
EndProcedure

Procedure ParseIniText(text$)
  Define.s section$ = "", line$, key$, value$
  Define.i i, count, separator, equals, colon, found
  ClearList(IniEntries())
  count = CountString(text$, Chr(10)) + 1
  For i = 1 To count
    line$ = Trim(ReplaceString(StringField(text$, i, Chr(10)), Chr(13), ""))
    If line$ = "" Or Left(line$, 1) = ";" Or Left(line$, 1) = "#"
      Continue
    EndIf
    If Left(line$, 1) = "[" And Right(line$, 1) = "]"
      section$ = Trim(Mid(line$, 2, Len(line$) - 2))
      Continue
    EndIf
    equals = FindString(line$, "=")
    colon = FindString(line$, ":")
    separator = equals
    If separator = 0 Or (colon > 0 And colon < separator)
      separator = colon
    EndIf
    If separator = 0
      Continue
    EndIf
    key$ = LCase(Trim(Left(line$, separator - 1)))
    value$ = Trim(Mid(line$, separator + 1))
    found = #False
    ForEach IniEntries()
      If IniEntries()\Section$ = section$ And IniEntries()\Key$ = key$
        IniEntries()\Value$ = value$
        found = #True
        Break
      EndIf
    Next
    If Not found
      LastElement(IniEntries()) : AddElement(IniEntries())
      IniEntries()\Section$ = section$
      IniEntries()\Key$ = key$
      IniEntries()\Value$ = value$
    EndIf
  Next
EndProcedure

Procedure.b IniHasSection(section$)
  ForEach IniEntries()
    If IniEntries()\Section$ = section$
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure.s IniGet(section$, key$, fallback$ = "")
  ForEach IniEntries()
    If IniEntries()\Section$ = section$ And IniEntries()\Key$ = key$
      ProcedureReturn IniEntries()\Value$
    EndIf
  Next
  ProcedureReturn fallback$
EndProcedure

; Returns the index for keys shaped like "<prefix><digits><suffix>", e.g. p0n.
; Returns -1 when the key does not match.
Procedure.i IniIndexKey(key$, prefix$, suffix$)
  Define.i length = Len(key$)
  Define.s digits$
  If length <= Len(prefix$) + Len(suffix$)
    ProcedureReturn -1
  EndIf
  If Left(key$, Len(prefix$)) <> prefix$ Or Right(key$, Len(suffix$)) <> suffix$
    ProcedureReturn -1
  EndIf
  digits$ = Mid(key$, Len(prefix$) + 1, length - Len(prefix$) - Len(suffix$))
  If Not IsDigitsOnly(digits$)
    ProcedureReturn -1
  EndIf
  ProcedureReturn Val(digits$)
EndProcedure

Procedure.s IniSectionText(name$)
  ProcedureReturn "[" + name$ + "]" + Chr(10)
EndProcedure
