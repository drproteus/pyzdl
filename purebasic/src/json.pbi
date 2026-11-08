; JSON reader and writer for pyZDL config files.
;
; PureBasic's built-in JSON library has no way to enumerate object keys, and the
; config format accepts name-keyed objects, so the whole tree is kept in memory
; instead. Node 0 is reserved as "no node".

Enumeration
  #JSON_Null
  #JSON_Bool
  #JSON_Number
  #JSON_String
  #JSON_Array
  #JSON_Object
EndEnumeration

Structure JNode
  Kind.i
  Key$
  Text$
  Flag.i
  FirstChild.i
  LastChild.i
  NextSibling.i
EndStructure

Global Dim JN.JNode(255)
Global JNCount.i
Global JError$
Global JSource$
Global JPos.i

Procedure JReset()
  JNCount = 0
EndProcedure

Procedure.i JNew(kind.i, key$ = "")
  JNCount + 1
  If JNCount > ArraySize(JN())
    ReDim JN(ArraySize(JN()) * 2 + 1)
  EndIf
  JN(JNCount)\Kind = kind
  JN(JNCount)\Key$ = key$
  JN(JNCount)\Text$ = ""
  JN(JNCount)\Flag = 0
  JN(JNCount)\FirstChild = 0
  JN(JNCount)\LastChild = 0
  JN(JNCount)\NextSibling = 0
  ProcedureReturn JNCount
EndProcedure

Procedure JAppend(parent.i, child.i)
  If JN(parent)\LastChild
    JN(JN(parent)\LastChild)\NextSibling = child
  Else
    JN(parent)\FirstChild = child
  EndIf
  JN(parent)\LastChild = child
EndProcedure

Procedure.i JAddString(parent.i, key$, value$)
  Define.i node = JNew(#JSON_String, key$)
  JN(node)\Text$ = value$
  JAppend(parent, node)
  ProcedureReturn node
EndProcedure

Procedure.i JAddNumber(parent.i, key$, value.i)
  Define.i node = JNew(#JSON_Number, key$)
  JN(node)\Text$ = Str(value)
  JAppend(parent, node)
  ProcedureReturn node
EndProcedure

Procedure.i JAddBool(parent.i, key$, value.i)
  Define.i node = JNew(#JSON_Bool, key$)
  JN(node)\Flag = Bool(value <> 0)
  JAppend(parent, node)
  ProcedureReturn node
EndProcedure

Procedure.i JAddNull(parent.i, key$)
  Define.i node = JNew(#JSON_Null, key$)
  JAppend(parent, node)
  ProcedureReturn node
EndProcedure

Procedure.i JAddObject(parent.i, key$)
  Define.i node = JNew(#JSON_Object, key$)
  JAppend(parent, node)
  ProcedureReturn node
EndProcedure

Procedure.i JAddArray(parent.i, key$)
  Define.i node = JNew(#JSON_Array, key$)
  JAppend(parent, node)
  ProcedureReturn node
EndProcedure

Procedure JSkipSpace()
  Define.s c$
  While JPos <= Len(JSource$)
    c$ = Mid(JSource$, JPos, 1)
    If c$ <> " " And c$ <> Chr(9) And c$ <> Chr(10) And c$ <> Chr(13)
      Break
    EndIf
    JPos + 1
  Wend
EndProcedure

Procedure.s JPeek()
  If JPos <= Len(JSource$)
    ProcedureReturn Mid(JSource$, JPos, 1)
  EndIf
  ProcedureReturn ""
EndProcedure

Procedure.s JReadString()
  Define.s result$ = "", c$, hex$
  JPos + 1
  While JPos <= Len(JSource$)
    c$ = Mid(JSource$, JPos, 1)
    If c$ = Chr(34)
      JPos + 1
      ProcedureReturn result$
    ElseIf c$ = "\"
      JPos + 1
      c$ = Mid(JSource$, JPos, 1)
      Select c$
        Case "n" : result$ + Chr(10)
        Case "r" : result$ + Chr(13)
        Case "t" : result$ + Chr(9)
        Case "b" : result$ + Chr(8)
        Case "f" : result$ + Chr(12)
        Case "u"
          hex$ = Mid(JSource$, JPos + 1, 4)
          result$ + Chr(Val("$" + hex$))
          JPos + 4
        Case Chr(34), "\", "/"
          result$ + c$
        Default
          JError$ = "Invalid escape in JSON string"
          ProcedureReturn ""
      EndSelect
    Else
      result$ + c$
    EndIf
    JPos + 1
  Wend
  JError$ = "Unterminated string in JSON"
  ProcedureReturn result$
EndProcedure

Declare.i JParseValue(key$ = "")

Procedure.i JParseObject(key$)
  Define.i node = JNew(#JSON_Object, key$)
  Define.i child, done = #False
  Define.s memberKey$
  JPos + 1
  JSkipSpace()
  If JPeek() = "}"
    JPos + 1
    ProcedureReturn node
  EndIf
  While Not done
    JSkipSpace()
    If JPeek() <> Chr(34)
      JError$ = "Expected a string key in JSON object"
      ProcedureReturn 0
    EndIf
    memberKey$ = JReadString()
    If JError$ <> "" : ProcedureReturn 0 : EndIf
    JSkipSpace()
    If JPeek() <> ":"
      JError$ = "Expected ':' in JSON object"
      ProcedureReturn 0
    EndIf
    JPos + 1
    child = JParseValue(memberKey$)
    If child = 0 : ProcedureReturn 0 : EndIf
    JAppend(node, child)
    JSkipSpace()
    If JPeek() = ","
      JPos + 1
    ElseIf JPeek() = "}"
      JPos + 1
      done = #True
    Else
      JError$ = "Expected ',' or '}' in JSON object"
      ProcedureReturn 0
    EndIf
  Wend
  ProcedureReturn node
EndProcedure

Procedure.i JParseArray(key$)
  Define.i node = JNew(#JSON_Array, key$)
  Define.i child, done = #False
  JPos + 1
  JSkipSpace()
  If JPeek() = "]"
    JPos + 1
    ProcedureReturn node
  EndIf
  While Not done
    child = JParseValue()
    If child = 0 : ProcedureReturn 0 : EndIf
    JAppend(node, child)
    JSkipSpace()
    If JPeek() = ","
      JPos + 1
    ElseIf JPeek() = "]"
      JPos + 1
      done = #True
    Else
      JError$ = "Expected ',' or ']' in JSON array"
      ProcedureReturn 0
    EndIf
  Wend
  ProcedureReturn node
EndProcedure

Procedure.i JParseValue(key$ = "")
  Define.i node, start
  Define.s c$
  JSkipSpace()
  If JPos > Len(JSource$)
    JError$ = "Unexpected end of JSON"
    ProcedureReturn 0
  EndIf
  c$ = Mid(JSource$, JPos, 1)
  If c$ = "{"
    ProcedureReturn JParseObject(key$)
  ElseIf c$ = "["
    ProcedureReturn JParseArray(key$)
  ElseIf c$ = Chr(34)
    node = JNew(#JSON_String, key$)
    JN(node)\Text$ = JReadString()
    If JError$ <> "" : ProcedureReturn 0 : EndIf
    ProcedureReturn node
  ElseIf Mid(JSource$, JPos, 4) = "true"
    node = JNew(#JSON_Bool, key$)
    JN(node)\Flag = #True
    JPos + 4
    ProcedureReturn node
  ElseIf Mid(JSource$, JPos, 5) = "false"
    node = JNew(#JSON_Bool, key$)
    JN(node)\Flag = #False
    JPos + 5
    ProcedureReturn node
  ElseIf Mid(JSource$, JPos, 4) = "null"
    node = JNew(#JSON_Null, key$)
    JPos + 4
    ProcedureReturn node
  ElseIf c$ = "-" Or (c$ >= "0" And c$ <= "9")
    start = JPos
    While JPos <= Len(JSource$) And FindString("0123456789+-.eE", Mid(JSource$, JPos, 1), 1) > 0
      JPos + 1
    Wend
    node = JNew(#JSON_Number, key$)
    JN(node)\Text$ = Mid(JSource$, start, JPos - start)
    ProcedureReturn node
  EndIf
  JError$ = "Unexpected character '" + c$ + "' in JSON"
  ProcedureReturn 0
EndProcedure

Procedure.i JParse(text$)
  Define.i root
  JReset()
  If Left(text$, 1) = Chr($FEFF)
    text$ = Mid(text$, 2)
  EndIf
  JSource$ = text$
  JPos = 1
  JError$ = ""
  root = JParseValue()
  If root And JError$ = ""
    JSkipSpace()
    If JPos <= Len(JSource$)
      JError$ = "Extra data after JSON value"
      root = 0
    EndIf
  EndIf
  ProcedureReturn root
EndProcedure

Procedure.i JGet(obj.i, key$)
  Define.i child
  If obj = 0 Or JN(obj)\Kind <> #JSON_Object
    ProcedureReturn 0
  EndIf
  child = JN(obj)\FirstChild
  While child
    If JN(child)\Key$ = key$
      ProcedureReturn child
    EndIf
    child = JN(child)\NextSibling
  Wend
  ProcedureReturn 0
EndProcedure

Procedure.i JHas(obj.i, key$)
  Define.i child = JGet(obj, key$)
  If child = 0 Or JN(child)\Kind = #JSON_Null
    ProcedureReturn #False
  EndIf
  ProcedureReturn #True
EndProcedure

Procedure.s JStr(obj.i, key$, fallback$ = "")
  Define.i child = JGet(obj, key$)
  If child And JN(child)\Kind = #JSON_String
    ProcedureReturn JN(child)\Text$
  EndIf
  ProcedureReturn fallback$
EndProcedure

Procedure.i JBool(obj.i, key$, fallback.i)
  Define.i child = JGet(obj, key$)
  If child And JN(child)\Kind = #JSON_Bool
    ProcedureReturn JN(child)\Flag
  EndIf
  ProcedureReturn fallback
EndProcedure

Procedure.i JInt(obj.i, key$, fallback.i)
  Define.i child = JGet(obj, key$)
  If child And JN(child)\Kind = #JSON_Number
    ProcedureReturn Val(JN(child)\Text$)
  EndIf
  ProcedureReturn fallback
EndProcedure

Procedure.s JEscape(text$)
  Define.s out$ = "", c$
  Define.i i
  For i = 1 To Len(text$)
    c$ = Mid(text$, i, 1)
    Select c$
      Case Chr(34) : out$ + "\" + Chr(34)
      Case "\" : out$ + "\\"
      Case Chr(10) : out$ + "\n"
      Case Chr(13) : out$ + "\r"
      Case Chr(9) : out$ + "\t"
      Default
        If Asc(c$) < 32
          out$ + "\u" + RSet(Hex(Asc(c$)), 4, "0")
        Else
          out$ + c$
        EndIf
    EndSelect
  Next
  ProcedureReturn out$
EndProcedure

; Pretty-prints with two-space indentation, like Python's json.dumps(indent=2).
Procedure.s JDump(node.i, depth.i = 0)
  Define.s out$, pad$, innerPad$
  Define.i child
  If node = 0
    ProcedureReturn "null"
  EndIf
  pad$ = Space(depth * 2)
  innerPad$ = Space(depth * 2 + 2)
  Select JN(node)\Kind
    Case #JSON_Null
      ProcedureReturn "null"
    Case #JSON_Bool
      If JN(node)\Flag
        ProcedureReturn "true"
      EndIf
      ProcedureReturn "false"
    Case #JSON_Number
      ProcedureReturn JN(node)\Text$
    Case #JSON_String
      ProcedureReturn Chr(34) + JEscape(JN(node)\Text$) + Chr(34)
    Case #JSON_Array
      If JN(node)\FirstChild = 0
        ProcedureReturn "[]"
      EndIf
      out$ = "[" + Chr(10)
      child = JN(node)\FirstChild
      While child
        out$ + innerPad$ + JDump(child, depth + 1)
        If JN(child)\NextSibling
          out$ + ","
        EndIf
        out$ + Chr(10)
        child = JN(child)\NextSibling
      Wend
      ProcedureReturn out$ + pad$ + "]"
    Case #JSON_Object
      If JN(node)\FirstChild = 0
        ProcedureReturn "{}"
      EndIf
      out$ = "{" + Chr(10)
      child = JN(node)\FirstChild
      While child
        out$ + innerPad$ + Chr(34) + JEscape(JN(child)\Key$) + Chr(34) + ": " + JDump(child, depth + 1)
        If JN(child)\NextSibling
          out$ + ","
        EndIf
        out$ + Chr(10)
        child = JN(child)\NextSibling
      Wend
      ProcedureReturn out$ + pad$ + "}"
  EndSelect
  ProcedureReturn "null"
EndProcedure
