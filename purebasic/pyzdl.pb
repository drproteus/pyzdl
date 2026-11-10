; pyZDL - a launcher for GZDoom and other Doom source ports.
;
; Build with build.ps1 (Windows) or build.sh (macOS and Linux). The program is
; portable: config.json and profiles\ live beside the executable.
;
; On Windows, `gui` relaunches itself detached with no console window, as the
; Python version does.

EnableExplicit

XIncludeFile "src\json.pbi"
XIncludeFile "src\platform.pbi"
XIncludeFile "src\core.pbi"
XIncludeFile "src\ini.pbi"
XIncludeFile "src\model.pbi"
XIncludeFile "src\launcher.pbi"
XIncludeFile "src\ports.pbi"
XIncludeFile "src\cli.pbi"
XIncludeFile "src\gui.pbi"
XIncludeFile "src\dialogs.pbi"

Define.i exitCode, scan
Define.b debugMode = #False

; The console is opened only for CLI output, so a detached GUI never shows one.
If Not ParseCli()
  End 2
EndIf

If Not CliHelp And ListSize(CliWords()) > 0 And WordAt(0) = "gui"
  For scan = 0 To CountProgramParameters() - 1
    If ProgramParameter(scan) = "--debug" Or ProgramParameter(scan) = "-v" Or ProgramParameter(scan) = "--verbose"
      debugMode = #True
    EndIf
  Next
  If Not debugMode And PlatformRelaunchDetached()
    End 0
  EndIf
  PlatformReleaseConsole()
  End RunGui(CliConfig$)
EndIf

OpenConsole()
exitCode = RunCli()
End exitCode
