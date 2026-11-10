; Platform-specific behaviour: command-line quoting, starting and tracking games,
; opening folders, detaching the GUI, and per-OS constants.
;
; Windows uses the Win32 API for process control and the Windows quoting rules.
; macOS and Linux run commands through /bin/sh. Win32 calls only appear inside
; CompilerIf blocks for Windows. Everything else is portable PureBasic, so the
; POSIX code compiles on any platform and can be syntax-checked on Windows.

Declare.b Fail(message$)

CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  #PYZ_IS_WINDOWS = #True
  #PYZ_IS_MACOS = #False
  #PYZ_PATHLIST$ = ";"
  #PYZ_FONT$ = "Segoe UI"
  #PYZ_OPENER$ = "explorer.exe"
  #PYZ_APP_PATTERN$ = "Programs (*.exe)|*.exe|All files (*.*)|*.*"
CompilerElseIf #PB_Compiler_OS = #PB_OS_MacOS
  #PYZ_IS_WINDOWS = #False
  #PYZ_IS_MACOS = #True
  #PYZ_PATHLIST$ = ":"
  #PYZ_FONT$ = "Helvetica Neue"
  #PYZ_OPENER$ = "open"
  #PYZ_APP_PATTERN$ = "Applications (*.app)|*.app|All files (*.*)|*.*"
CompilerElse
  #PYZ_IS_WINDOWS = #False
  #PYZ_IS_MACOS = #False
  #PYZ_PATHLIST$ = ":"
  #PYZ_FONT$ = "Sans"
  #PYZ_OPENER$ = "xdg-open"
  #PYZ_APP_PATTERN$ = "All files (*.*)|*.*"
CompilerEndIf

#PYZ_DETACHED_PROCESS = 8
#PYZ_FILE_APPEND_DATA = $4
#PYZ_GENERIC_READ = $80000000
#PYZ_SHARE_RW = 3
#PYZ_OPEN_ALWAYS = 4
#PYZ_OPEN_EXISTING = 3
#PYZ_FILE_ATTRIBUTE_NORMAL = $80
#PYZ_WAIT_OBJECT_0 = 0

Structure SecAttr
  nLength.l
  padding.l
  lpSecurityDescriptor.i
  bInheritHandle.l
  padding2.l
EndStructure

Procedure.s Backslashes(count.i)
  ProcedureReturn ReplaceString(Space(count), " ", "\")
EndProcedure

; Windows rules for one argument, like subprocess.list2cmdline.
Procedure.s WindowsArgQuote(arg$)
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

; POSIX shell quoting. Plain words pass through; anything else is single-quoted.
Procedure.s PosixArgQuote(arg$)
  Define.i i
  Define.s c$
  Define.b plain = #True
  If arg$ = ""
    ProcedureReturn "''"
  EndIf
  For i = 1 To Len(arg$)
    c$ = Mid(arg$, i, 1)
    If FindString("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-./:=+,@%", c$, 1) = 0
      plain = #False
      Break
    EndIf
  Next
  If plain
    ProcedureReturn arg$
  EndIf
  ProcedureReturn "'" + ReplaceString(arg$, "'", "'\''") + "'"
EndProcedure

Procedure.s ArgQuote(arg$)
  If #PYZ_IS_WINDOWS
    ProcedureReturn WindowsArgQuote(arg$)
  EndIf
  ProcedureReturn PosixArgQuote(arg$)
EndProcedure

Procedure RunShell(command$)
  RunProgram("/bin/sh", "-c " + ArgQuote(command$), "")
EndProcedure

Procedure OpenPathInShell(path$)
  If #PYZ_IS_WINDOWS
    RunProgram(#PYZ_OPENER$, ArgQuote(path$), "")
  Else
    RunShell(#PYZ_OPENER$ + " " + ArgQuote(path$))
  EndIf
EndProcedure

; Starts a Windows process with stdout and stderr appended to logPath$.
; Returns the process handle, or 0 with LastError$ set.
Procedure.i WinStartProcess(command$, cwd$, logPath$)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Define.SecAttr sa
    Define.STARTUPINFO si
    Define.PROCESS_INFORMATION pi
    Define.i logHandle, nulHandle, ok, cwdPointer
    Define.s cmd$ = command$
    sa\nLength = SizeOf(SecAttr)
    sa\bInheritHandle = #True
    logHandle = CreateFile_(logPath$, #PYZ_FILE_APPEND_DATA, #PYZ_SHARE_RW, @sa, #PYZ_OPEN_ALWAYS, #PYZ_FILE_ATTRIBUTE_NORMAL, 0)
    nulHandle = CreateFile_("NUL", #PYZ_GENERIC_READ, #PYZ_SHARE_RW, @sa, #PYZ_OPEN_EXISTING, #PYZ_FILE_ATTRIBUTE_NORMAL, 0)
    If nulHandle = -1
      ProcedureReturn Fail("Could not open NUL for " + command$)
    EndIf
    If logHandle = -1
      logHandle = nulHandle
    EndIf
    si\cb = SizeOf(STARTUPINFO)
    si\dwFlags = #STARTF_USESTDHANDLES
    si\hStdInput = nulHandle
    si\hStdOutput = logHandle
    si\hStdError = logHandle
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
      ProcedureReturn Fail("Could not start " + command$ + " (error " + Str(GetLastError_()) + ")")
    EndIf
    CloseHandle_(pi\hThread)
    ProcedureReturn pi\hProcess
  CompilerElse
    ProcedureReturn 0
  CompilerEndIf
EndProcedure

; Starts a POSIX command through the shell. The exec replaces the shell, so the
; returned program is the game itself.
Procedure.i PosixStartProcess(command$, cwd$, logPath$)
  Define.i id
  Define.s shellCommand$
  shellCommand$ = "exec " + command$ + " >> " + ArgQuote(logPath$) + " 2>&1 < /dev/null"
  id = RunProgram("/bin/sh", "-c " + ArgQuote(shellCommand$), cwd$, #PB_Program_Open)
  If id = 0
    ProcedureReturn Fail("Could not start " + command$)
  EndIf
  ProcedureReturn id
EndProcedure

; Starts a game command with its output going to logPath$. Returns a handle
; for TryReapGame and PlatformDetachGame, or 0 with LastError$ set. The
; environment must already be set up by the caller.
Procedure.i PlatformStartProcess(command$, cwd$, logPath$)
  If #PYZ_IS_WINDOWS
    ProcedureReturn WinStartProcess(command$, cwd$, logPath$)
  EndIf
  ProcedureReturn PosixStartProcess(command$, cwd$, logPath$)
EndProcedure

; Returns #True once when the game has exited, storing its exit code in *code.
Procedure.b TryReapGame(handle.i, *code.Long)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If WaitForSingleObject_(handle, 0) = #PYZ_WAIT_OBJECT_0
      GetExitCodeProcess_(handle, *code)
      CloseHandle_(handle)
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
  CompilerElse
    If Not ProgramRunning(handle)
      *code\l = ProgramExitCode(handle)
      CloseProgram(handle)
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
  CompilerEndIf
EndProcedure

; Stops tracking a game without waiting for it. The game keeps running.
Procedure PlatformDetachGame(handle.i)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    CloseHandle_(handle)
  CompilerElse
    ; Nothing to release: the POSIX handle is closed when the game is reaped.
  CompilerEndIf
EndProcedure

; Starts the GUI in a separate process with no console window. Returns #True when
; a detached copy was started and this process should exit.
Procedure.b PlatformRelaunchDetached()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Define.i i, count = CountProgramParameters()
    Define.s args$ = ""
    Define.STARTUPINFO si
    Define.PROCESS_INFORMATION pi
    Define.s cmd$
    If GetEnvironmentVariable("PYZDL_DETACHED") <> ""
      ProcedureReturn #False
    EndIf
    For i = 0 To count - 1
      args$ + " " + ArgQuote(ProgramParameter(i))
    Next
    cmd$ = ArgQuote(ProgramFilename()) + args$
    SetEnvironmentVariable("PYZDL_DETACHED", "1")
    si\cb = SizeOf(STARTUPINFO)
    If Not CreateProcess_(0, @cmd$, 0, 0, #False, #PYZ_DETACHED_PROCESS, 0, 0, @si, @pi)
      ProcedureReturn #False
    EndIf
    CloseHandle_(pi\hThread)
    CloseHandle_(pi\hProcess)
    ProcedureReturn #True
  CompilerElse
    ProcedureReturn #False
  CompilerEndIf
EndProcedure

; Called in a detached GUI process so that it has no console window.
Procedure PlatformReleaseConsole()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If GetEnvironmentVariable("PYZDL_DETACHED") <> ""
      FreeConsole_()
    EndIf
  CompilerEndIf
EndProcedure

Procedure.b PlatformIsDetachedGui()
  ProcedureReturn Bool(GetEnvironmentVariable("PYZDL_DETACHED") <> "")
EndProcedure
