; pyZDL - a launcher for GZDoom and other Doom source ports.
;
; Build with build.ps1, or:
;   pbcompiler pyzdl.pb /CONSOLE /ICON ..\assets\pyzdl-launcher.ico /OUTPUT build\pyZDL.exe
;
; The program is a console application so that the CLI can print to a terminal.
; `gui` relaunches itself detached with no console window, like the Python version.

EnableExplicit

XIncludeFile "src\json.pbi"
XIncludeFile "src\core.pbi"
XIncludeFile "src\ini.pbi"
XIncludeFile "src\model.pbi"
XIncludeFile "src\launcher.pbi"
XIncludeFile "src\ports.pbi"
XIncludeFile "src\cli.pbi"
XIncludeFile "src\gui.pbi"
XIncludeFile "src\dialogs.pbi"

#PYZ_DETACHED_MARKER = "PYZDL_DETACHED"

Procedure.b RelaunchDetached()
  Define.i i, count = CountProgramParameters()
  Define.s args$ = ""
  Define.i handle
  Define.STARTUPINFO si
  Define.PROCESS_INFORMATION pi
  Define.s cmd$
  If GetEnvironmentVariable(#PYZ_DETACHED_MARKER) <> ""
    ProcedureReturn #False
  EndIf
  For i = 0 To count - 1
    args$ + " " + CmdQuote(ProgramParameter(i))
  Next
  cmd$ = CmdQuote(ProgramFilename()) + args$
  SetEnvironmentVariable(#PYZ_DETACHED_MARKER, "1")
  si\cb = SizeOf(STARTUPINFO)
  If Not CreateProcess_(0, @cmd$, 0, 0, #False, #PYZ_DETACHED_PROCESS, 0, 0, @si, @pi)
    ProcedureReturn #False
  EndIf
  CloseHandle_(pi\hThread)
  CloseHandle_(pi\hProcess)
  ProcedureReturn #True
EndProcedure

OpenConsole()

Define.i exitCode, scan
Define.b debugMode = #False

If Not ParseCli()
  End 2
EndIf

If Not CliHelp And ListSize(CliWords()) > 0 And WordAt(0) = "gui"
  For scan = 0 To CountProgramParameters() - 1
    If ProgramParameter(scan) = "--debug" Or ProgramParameter(scan) = "-v" Or ProgramParameter(scan) = "--verbose"
      debugMode = #True
    EndIf
  Next
  If Not debugMode And RelaunchDetached()
    End 0
  EndIf
  If GetEnvironmentVariable(#PYZ_DETACHED_MARKER) <> ""
    FreeConsole_()
  EndIf
  End RunGui(CliConfig$)
EndIf

exitCode = RunCli()
End exitCode
