; Command-line interface. Mirrors cli.py: the same command names, options, and
; exit codes (0 success, 1 for errors reported to the user, 2 for usage errors).

Global NewList CliWords.s()
Global NewList CliExtra.s()
Global NewList CliFiles.s()
Global CliConfig$
Global CliFormat$
Global CliHelp.b

Procedure CliError(message$)
  OpenConsole()
  ConsoleError("Error: " + message$)
EndProcedure

Procedure PrintUsage()
  Print("Usage: pyZDL [--config PATH] COMMAND [ARGS]..." + Chr(10))
  Print(Chr(10))
  Print("A launcher for GZDoom and other Doom source ports." + Chr(10))
  Print(Chr(10))
  Print("Commands:" + Chr(10))
  Print("  gui                          Start the graphical interface" + Chr(10))
  Print("  profiles ls                  List profiles" + Chr(10))
  Print("  profiles launch-args NAME    Show the command a profile would run" + Chr(10))
  Print("  profiles add NAME PORT IWAD [--file PATH]..." + Chr(10))
  Print("  profiles rm NAME             Delete a profile" + Chr(10))
  Print("  profiles import PATH [NAME]  Import a .json, .zdl, or .ini profile" + Chr(10))
  Print("  profiles inspect NAME [--format json|zdl|ini]" + Chr(10))
  Print("  ports ls | add NAME PATH | rm NAME" + Chr(10))
  Print("  iwads ls | add NAME PATH | rm NAME" + Chr(10))
  Print("  config inspect [--format json|zdl|ini]" + Chr(10))
  Print("  config edit [EDITOR]         Open the config in an editor" + Chr(10))
  Print("  config validate              Check every profile" + Chr(10))
  Print("  run profile [NAME] [ARGS]... Launch a profile" + Chr(10))
  Print("  run zdl PATH [ARGS]...       Launch a .zdl or .ini file" + Chr(10))
EndProcedure

Procedure.b NeedWord(index.i, label$)
  If index >= ListSize(CliWords())
    CliError("Missing argument '" + label$ + "'.")
    ProcedureReturn #False
  EndIf
  ProcedureReturn #True
EndProcedure

Procedure.s WordAt(index.i)
  Define.i seen = 0
  ForEach CliWords()
    If seen = index
      ProcedureReturn CliWords()
    EndIf
    seen + 1
  Next
  ProcedureReturn ""
EndProcedure

Procedure.b ParseCli()
  Define.i count, i
  Define.s token$
  ClearList(CliWords())
  ClearList(CliExtra())
  ClearList(CliFiles())
  CliConfig$ = ""
  CliFormat$ = ""
  CliHelp = #False
  count = CountProgramParameters()
  i = 0
  While i < count
    token$ = ProgramParameter(i)
    i + 1
    If ListSize(CliWords()) = 3 And WordAt(0) = "run"
      LastElement(CliExtra()) : AddElement(CliExtra())
      CliExtra() = token$
    ElseIf token$ = "--config" Or token$ = "--format" Or token$ = "--file"
      If i >= count
        CliError("Option '" + token$ + "' requires an argument.")
        ProcedureReturn #False
      EndIf
      If token$ = "--config"
        CliConfig$ = ProgramParameter(i)
      ElseIf token$ = "--format"
        CliFormat$ = ProgramParameter(i)
      Else
        LastElement(CliFiles()) : AddElement(CliFiles())
        CliFiles() = ProgramParameter(i)
      EndIf
      i + 1
    ElseIf Left(token$, 9) = "--config="
      CliConfig$ = Mid(token$, 10)
    ElseIf Left(token$, 9) = "--format="
      CliFormat$ = Mid(token$, 10)
    ElseIf token$ = "--help" Or token$ = "-h"
      CliHelp = #True
    ElseIf token$ = "--debug" Or token$ = "--verbose" Or token$ = "-v"
      Continue
    Else
      LastElement(CliWords()) : AddElement(CliWords())
      CliWords() = token$
    EndIf
  Wend
  If CliConfig$ = ""
    CliConfig$ = DefaultConfigPath()
  EndIf
  ProcedureReturn #True
EndProcedure

Procedure.i CmdProfilesLs()
  ForEach Profiles()
    Print(Profiles()\Name$ + " (" + Profiles()\PortName$ + ")" + Chr(10))
  Next
  ProcedureReturn 0
EndProcedure

Procedure.i CmdProfilesLaunchArgs()
  Define.s name$
  Define.i ptr
  If Not NeedWord(2, "NAME")
    ProcedureReturn 2
  EndIf
  name$ = WordAt(2)
  ptr = FindProfilePtr(name$)
  If ptr = 0
    CliError("Could not find profile " + name$ + ".")
    ProcedureReturn 1
  EndIf
  Define *p.Profile = ptr
  If Not BuildLaunch(*p)
    CliError(LastError$)
    ProcedureReturn 1
  EndIf
  Print(CommandPreview() + Chr(10))
  ProcedureReturn 0
EndProcedure

Procedure.i CmdPortsLs()
  ForEach Ports()
    Print(Ports()\Name$ + " (" + Ports()\Path$ + ")" + Chr(10))
  Next
  ProcedureReturn 0
EndProcedure

Procedure.i CmdIwadsLs()
  ForEach Iwads()
    Print(Iwads()\Name$ + " (" + Iwads()\Path$ + ")" + Chr(10))
  Next
  ProcedureReturn 0
EndProcedure

Procedure.i CmdAddResource(isPort.b)
  Define.s name$, path$
  If Not NeedWord(2, "NAME")
    ProcedureReturn 2
  EndIf
  If Not NeedWord(3, "PATH")
    ProcedureReturn 2
  EndIf
  name$ = WordAt(2)
  path$ = WordAt(3)
  If Not PathExists(path$)
    CliError("Invalid value for 'PATH': Path '" + path$ + "' does not exist.")
    ProcedureReturn 2
  EndIf
  If isPort
    If Not AddPortEntry(name$, path$)
      CliError(LastError$)
      ProcedureReturn 1
    EndIf
  Else
    If Not AddIwadEntry(name$, path$)
      CliError(LastError$)
      ProcedureReturn 1
    EndIf
  EndIf
  If Not WriteConfig()
    CliError(LastError$)
    ProcedureReturn 1
  EndIf
  ProcedureReturn 0
EndProcedure

Procedure.i CmdRemoveResource(isPort.b)
  Define.s name$
  Define.b removed
  If Not NeedWord(2, "NAME")
    ProcedureReturn 2
  EndIf
  name$ = WordAt(2)
  If isPort
    removed = RemovePortEntry(name$)
  Else
    removed = RemoveIwadEntry(name$)
  EndIf
  If removed = #False And LastError$ <> ""
    CliError(LastError$)
    ProcedureReturn 1
  EndIf
  If removed And Not WriteConfig()
    CliError(LastError$)
    ProcedureReturn 1
  EndIf
  ProcedureReturn 0
EndProcedure

Procedure.i CmdProfilesAdd()
  Define.s name$, port$, iwad$
  Define.i id
  If Not NeedWord(2, "NAME")
    ProcedureReturn 2
  EndIf
  If Not NeedWord(3, "PORT")
    ProcedureReturn 2
  EndIf
  If Not NeedWord(4, "IWAD")
    ProcedureReturn 2
  EndIf
  name$ = WordAt(2)
  port$ = WordAt(3)
  iwad$ = WordAt(4)
  ForEach CliFiles()
    If Not PathExists(CliFiles())
      CliError("Invalid value for '--file': Path '" + CliFiles() + "' does not exist.")
      ProcedureReturn 2
    EndIf
  Next
  id = AddProfileEntry(name$, port$, iwad$)
  If id = 0
    CliError(LastError$)
    ProcedureReturn 1
  EndIf
  ForEach CliFiles()
    AddProfileFile(id, CliFiles(), #True)
  Next
  If Not WriteConfig()
    CliError(LastError$)
    ProcedureReturn 1
  EndIf
  ProcedureReturn 0
EndProcedure

Procedure.i CmdProfilesRemove()
  Define.s name$
  If Not NeedWord(2, "NAME")
    ProcedureReturn 2
  EndIf
  name$ = WordAt(2)
  If RemoveProfileEntry(name$) And Not WriteConfig()
    CliError(LastError$)
    ProcedureReturn 1
  EndIf
  ProcedureReturn 0
EndProcedure

Procedure.i CmdProfilesImport()
  Define.s path$, name$
  Define.i id
  If Not NeedWord(2, "PATH")
    ProcedureReturn 2
  EndIf
  path$ = WordAt(2)
  name$ = ""
  If ListSize(CliWords()) > 3
    name$ = WordAt(3)
  EndIf
  id = ImportProfileFile(path$, name$)
  If id = 0
    CliError(LastError$)
    ProcedureReturn 1
  EndIf
  If Not WriteConfig()
    CliError(LastError$)
    ProcedureReturn 1
  EndIf
  ProcedureReturn 0
EndProcedure

Procedure.i CmdProfilesInspect()
  Define.s name$, format$
  Define.i root, ptr
  If Not NeedWord(2, "NAME")
    ProcedureReturn 2
  EndIf
  name$ = WordAt(2)
  ptr = FindProfilePtr(name$)
  If ptr = 0
    CliError("Could not find profile '" + name$ + "'.")
    ProcedureReturn 1
  EndIf
  Define *p.Profile = ptr
  format$ = LCase(CliFormat$)
  If format$ = "" Or format$ = "json"
    JReset()
    root = JNew(#JSON_Array)
    ProfileNode(*p, root, #True)
    Print(JDump(JN(root)\FirstChild) + Chr(10))
  ElseIf format$ = "zdl" Or format$ = "ini"
    Print(ProfileZdlText(*p))
  Else
    CliError("Invalid value for '--format': '" + CliFormat$ + "'.")
    ProcedureReturn 2
  EndIf
  ProcedureReturn 0
EndProcedure

Procedure.i CmdConfigInspect()
  Define.s format$ = LCase(CliFormat$)
  If format$ = "" Or format$ = "json"
    Print(ConfigJsonText())
  ElseIf format$ = "zdl" Or format$ = "ini"
    Print(AppZdlText())
  Else
    CliError("Invalid value for '--format': '" + CliFormat$ + "'.")
    ProcedureReturn 2
  EndIf
  ProcedureReturn 0
EndProcedure

Procedure.i CmdConfigEdit()
  Define.s editor$ = WordAt(2)
  If editor$ = ""
    editor$ = GetEnvironmentVariable("EDITOR")
  EndIf
  If editor$ = ""
    CliError("Set $EDITOR or pass an editor command.")
    ProcedureReturn 1
  EndIf
  RunProgram(editor$, ArgQuote(ConfigPath$), "", #PB_Program_Wait)
  ProcedureReturn 0
EndProcedure

Procedure.i CmdConfigValidate()
  Define.s errors$ = ""
  ForEach Profiles()
    Define *p.Profile = @Profiles()
    If Not BuildLaunch(*p)
      errors$ + Profiles()\Name$ + ": " + LastError$ + Chr(10)
    EndIf
  Next
  If errors$ <> ""
    CliError(Trim(errors$))
    ProcedureReturn 1
  EndIf
  Print("Configuration OK" + Chr(10))
  ProcedureReturn 0
EndProcedure

Procedure.i CmdRunProfile()
  Define.s name$
  Define.i ptr, handle
  If ListSize(Profiles()) = 0
    CliError("No available profiles.")
    ProcedureReturn 1
  EndIf
  If ListSize(CliWords()) > 2
    name$ = WordAt(2)
  Else
    FirstElement(Profiles())
    name$ = Profiles()\Name$
    ConsoleError("No profile given, assuming " + name$ + ".")
  EndIf
  ptr = FindProfilePtr(name$)
  If ptr = 0
    CliError("Could not find profile " + name$ + " in config.")
    ProcedureReturn 1
  EndIf
  ClearList(ExtraArgs())
  ForEach CliExtra()
    LastElement(ExtraArgs()) : AddElement(ExtraArgs())
    ExtraArgs() = CliExtra()
  Next
  Define *p.Profile = ptr
  handle = LaunchProfile(*p)
  ClearList(ExtraArgs())
  If handle = 0
    CliError(LastError$)
    ProcedureReturn 1
  EndIf
  PlatformDetachGame(handle)
  ProcedureReturn 0
EndProcedure

Procedure.i CmdRunZdl()
  Define.s path$, name$
  Define.i handle
  If Not NeedWord(2, "PATH")
    ProcedureReturn 2
  EndIf
  path$ = WordAt(2)
  If Not IsFilePath(path$)
    CliError("ZDL file not found: " + path$)
    ProcedureReturn 1
  EndIf
  name$ = StemName(path$)
  If Not LoadZdlProfileText(ReadTextFile(path$), name$)
    ClearZdlProfile()
    CliError(LastError$)
    ProcedureReturn 1
  EndIf
  ClearList(ExtraArgs())
  ForEach CliExtra()
    LastElement(ExtraArgs()) : AddElement(ExtraArgs())
    ExtraArgs() = CliExtra()
  Next
  handle = LaunchProfile(@ZdlProfile)
  ClearList(ExtraArgs())
  ClearZdlProfile()
  If handle = 0
    CliError(LastError$)
    ProcedureReturn 1
  EndIf
  PlatformDetachGame(handle)
  ProcedureReturn 0
EndProcedure

Procedure.i CmdValidateCommand(command$)
  Define.s group$ = WordAt(0)
  Define.s sub$ = WordAt(1)
  If group$ = "profiles"
    Select sub$
      Case "ls" : ProcedureReturn CmdProfilesLs()
      Case "launch-args" : ProcedureReturn CmdProfilesLaunchArgs()
      Case "add" : ProcedureReturn CmdProfilesAdd()
      Case "rm" : ProcedureReturn CmdProfilesRemove()
      Case "import" : ProcedureReturn CmdProfilesImport()
      Case "inspect" : ProcedureReturn CmdProfilesInspect()
    EndSelect
  ElseIf group$ = "ports"
    Select sub$
      Case "ls" : ProcedureReturn CmdPortsLs()
      Case "add" : ProcedureReturn CmdAddResource(#True)
      Case "rm" : ProcedureReturn CmdRemoveResource(#True)
    EndSelect
  ElseIf group$ = "iwads"
    Select sub$
      Case "ls" : ProcedureReturn CmdIwadsLs()
      Case "add" : ProcedureReturn CmdAddResource(#False)
      Case "rm" : ProcedureReturn CmdRemoveResource(#False)
    EndSelect
  ElseIf group$ = "config"
    Select sub$
      Case "inspect" : ProcedureReturn CmdConfigInspect()
      Case "edit" : ProcedureReturn CmdConfigEdit()
      Case "validate" : ProcedureReturn CmdConfigValidate()
    EndSelect
  ElseIf group$ = "run"
    Select sub$
      Case "profile" : ProcedureReturn CmdRunProfile()
      Case "zdl" : ProcedureReturn CmdRunZdl()
    EndSelect
  EndIf
  CliError("No such command '" + command$ + "'.")
  ProcedureReturn 2
EndProcedure

; Runs one CLI command and returns the process exit code. The caller handles the
; `gui` command itself.
Procedure.i RunCli()
  Define.s group$
  If Not ParseCli()
    ProcedureReturn 2
  EndIf
  If CliHelp Or ListSize(CliWords()) = 0
    PrintUsage()
    ProcedureReturn 0
  EndIf
  group$ = WordAt(0)
  If group$ = "help"
    PrintUsage()
    ProcedureReturn 0
  EndIf
  If Not LoadConfig(CliConfig$)
    CliError(LastError$)
    ProcedureReturn 1
  EndIf
  ProcedureReturn CmdValidateCommand(group$)
EndProcedure
