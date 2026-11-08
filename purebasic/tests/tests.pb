; Unit tests for the PureBasic port. build.ps1 compiles and runs this file; it
; exits non-zero when any check fails.

EnableExplicit

XIncludeFile "..\src\json.pbi"
XIncludeFile "..\src\core.pbi"
XIncludeFile "..\src\ini.pbi"
XIncludeFile "..\src\model.pbi"
XIncludeFile "..\src\launcher.pbi"
XIncludeFile "..\src\ports.pbi"

Global TestCount.i
Global TestFailed.i
Global TestRoot$

; A macro so that conditions can use comparisons, which PureBasic only allows inside If.
Macro Check(condition, label)
  TestCount + 1
  If Not (condition)
    TestFailed + 1
    ConsoleError("FAIL: " + label)
  EndIf
EndMacro

Procedure CheckEqual(actual$, expected$, label$)
  TestCount + 1
  If actual$ <> expected$
    TestFailed + 1
    ConsoleError("FAIL: " + label$ + Chr(10) + "  expected: [" + expected$ + "]" + Chr(10) + "  actual:   [" + actual$ + "]")
  EndIf
EndProcedure

; A JSON string literal. Backslashes are escaped so Windows paths stay valid JSON.
Procedure.s Q(text$)
  ProcedureReturn Chr(34) + ReplaceString(text$, "\", "\\") + Chr(34)
EndProcedure

Procedure.s Quote(text$)
  ProcedureReturn Chr(34) + text$ + Chr(34)
EndProcedure

Procedure.s TempFile(name$)
  ProcedureReturn PathJoin(TestRoot$, name$)
EndProcedure

Procedure WriteFixture(name$, text$)
  WriteTextFile(TempFile(name$), text$)
EndProcedure

Procedure.s JoinArgs()
  Define.s joined$ = ""
  ForEach SpecArgs()
    joined$ + "|" + SpecArgs()
  Next
  ProcedureReturn joined$ + "|"
EndProcedure

Procedure TestJson()
  Define.i root
  root = JParse("{" + Quote("a") + ": [1, 2.5, true, null, " + Quote("x\u0041") + "], " + Quote("b") + ": {}}")
  Check(Bool(root <> 0), "json parses an object with mixed values")
  If root
    CheckEqual(JDump(root), "{" + Chr(10) + "  " + Quote("a") + ": [" + Chr(10) + "    1," + Chr(10) + "    2.5," + Chr(10) + "    true," + Chr(10) + "    null," + Chr(10) + "    " + Quote("xA") + Chr(10) + "  ]," + Chr(10) + "  " + Quote("b") + ": {}" + Chr(10) + "}", "json dumps with two-space indent")
  EndIf
  Check(Bool(JParse("{" + Quote("a") + ": " + Quote("bad\q") + "}") = 0), "json rejects an invalid string escape")
  Check(Bool(JParse("{" + Quote("a") + ": 1,}") = 0), "json rejects a trailing comma")
  Check(Bool(JParse("[1] x") = 0), "json rejects trailing data")
  Check(Bool(JParse("abc") = 0), "json rejects bare text")
EndProcedure

Procedure TestPaths()
  CheckEqual(ExpandPath("a/b/../c", "C:\base"), "C:\base\a\c", "expand_path joins relative paths and normalises")
  CheckEqual(ExpandPath("C:\games\\.\doom.wad"), "C:\games\doom.wad", "expand_path collapses dot segments")
  CheckEqual(ExpandPath(""), "", "expand_path keeps empty input empty")
  CheckEqual(DirName("C:\a\b.exe"), "C:\a", "dirname of a file")
  CheckEqual(DirName("C:\b.exe"), "C:\", "dirname of a root file")
  CheckEqual(BaseName("C:\a\b.exe"), "b.exe", "basename")
  CheckEqual(ExtLower("C:\a\B.PK3"), ".pk3", "extension is lower-cased")
  CheckEqual(StemName("C:\a\gz.doom.exe"), "gz.doom", "stem keeps inner dots")
  Check(Bool(IsAbsPath("C:\x") And IsAbsPath("\x") And Not IsAbsPath("x\y")), "absolute path detection")
EndProcedure

Procedure TestCommandLine()
  CheckEqual(CmdQuote("a b"), Quote("a b"), "quotes arguments with spaces")
  CheckEqual(CmdQuote("plain"), "plain", "leaves simple arguments alone")
  CheckEqual(CmdQuote(""), Quote(""), "quotes empty arguments")
  CheckEqual(CmdQuote("x\" + Chr(34) + "y"), Quote("x\\\" + Chr(34) + "y"), "escapes embedded quotes like list2cmdline")
EndProcedure

Procedure TestSplitArgs()
  Check(SplitArgs("-name " + Quote("my name") + " -skill 4"), "split_args accepts quoted text")
  Check(Bool(ListSize(SplitOut()) = 4), "split_args returns four tokens")
  FirstElement(SplitOut())
  CheckEqual(SplitOut(), "-name", "first token")
  NextElement(SplitOut())
  CheckEqual(SplitOut(), "my name", "quoted token keeps spaces and loses quotes")
  Check(SplitArgs("a" + Chr(10) + "b") And Bool(ListSize(SplitOut()) = 2), "newlines separate tokens")
  Check(Not SplitArgs(Quote("open") + " " + Chr(34)), "split_args rejects an unterminated quote")
  CheckEqual(LastError$, "Could not parse extra arguments: No closing quotation", "split_args error message")
EndProcedure

Procedure TestConfigListForm()
  Define.s json$
  json$ = "{" + Quote("version") + ": 2, " + Quote("source_ports") + ": [{" + Quote("name") + ": " + Quote("Echo") + ", " + Quote("executable") + ": " + Q(TestRoot$) + "}], " + Quote("iwads") + ": [{" + Quote("name") + ": " + Quote("Doom") + ", " + Quote("file") + ": " + Q(TempFile("DOOM.WAD")) + "}], " + Quote("profiles") + ": [{" + Quote("name") + ": " + Quote("Test") + ", " + Quote("port") + ": " + Quote("Echo") + ", " + Quote("iwad") + ": " + Quote("Doom") + ", " + Quote("files") + ": [" + Quote("mod.pk3") + ", {" + Quote("path") + ": " + Quote("patch.deh") + ", " + Quote("enabled") + ": false}], " + Quote("args") + ": " + Quote("-timedemo x") + "}]}"
  WriteFixture("list.json", json$)
  Check(LoadConfig(TempFile("list.json")), "list-form config loads: " + LastError$)
  Check(Bool(ListSize(Ports()) = 1 And ListSize(Iwads()) = 1 And ListSize(Profiles()) = 1), "list-form config has one of each")
  Check(Bool(ListSize(ProfileFiles()) = 2), "list-form config keeps both mod entries")
  Define.i ptr = FindProfilePtr("Test")
  Check(Bool(ptr <> 0), "profile is found by name")
  If ptr
    Define *p.Profile = ptr
    CheckEqual(ProfileFolderName(*p), "Test", "folder defaults to the safe profile name")
    Check(Bool(ProfileFileCount(*p\ID) = 2), "files belong to their profile")
  EndIf
EndProcedure

Procedure TestConfigMapForm()
  Define.s json$
  json$ = "{" + Quote("source_ports") + ": {" + Quote("Echo") + ": {" + Quote("executable") + ": " + Q(TestRoot$) + "}}, " + Quote("iwads") + ": {" + Quote("Doom") + ": {" + Quote("file") + ": " + Q(TempFile("DOOM.WAD")) + "}}, " + Quote("profiles") + ": {" + Quote("Map") + ": {" + Quote("port") + ": " + Quote("Echo") + ", " + Quote("iwad") + ": " + Quote("Doom") + "}}}"
  WriteFixture("map.json", json$)
  Check(LoadConfig(TempFile("map.json")), "name-keyed config loads: " + LastError$)
  Check(Bool(FindPortPtr("Echo") <> 0 And FindIwadPtr("Doom") <> 0 And FindProfilePtr("Map") <> 0), "name-keyed entries take their key as name")
EndProcedure

Procedure TestConfigErrors()
  WriteFixture("bad-port.json", "{" + Quote("source_ports") + ": [], " + Quote("iwads") + ": [], " + Quote("profiles") + ": [{" + Quote("name") + ": " + Quote("X") + ", " + Quote("port") + ": " + Quote("Missing") + ", " + Quote("iwad") + ": " + Quote("Doom") + "}]}")
  Check(Not LoadConfig(TempFile("bad-port.json")), "unknown port reference is reported")
  CheckEqual(LastError$, "Profile 'X' references unknown source port 'Missing'.", "unknown port message")
  WriteFixture("broken.json", "{not json")
  Check(Not LoadConfig(TempFile("broken.json")), "invalid JSON is reported")
  WriteFixture("unknown.txt", "hello")
  Check(Not LoadConfig(TempFile("unknown.txt")), "unknown config format is reported")
EndProcedure

Procedure TestDefaultsAndSettings()
  Define.s json$
  json$ = "{" + Quote("settings") + ": {" + Quote("profile_saves") + ": true, " + Quote("vars") + ": {" + Quote("doomwaddir") + ": " + Q("D:\Doom") + "}}}"
  WriteFixture("settings.json", json$)
  Check(LoadConfig(TempFile("settings.json")), "config with only settings loads")
  Check(Bool(SettingProfileSaves = #True), "profile_saves is read")
  Check(Bool(SettingProfileConfigs = #True), "profile_configs defaults to true")
  CheckEqual(DoomWadDir(), "D:\Doom", "DOOMWADDIR override is used")
  Check(LoadConfig(TempFile("fresh.json")), "missing config file starts empty")
  Check(Bool(SettingProfileSaves = #True), "new config enables save isolation like the Python defaults")
  Check(Bool(ListSize(Profiles()) = 0), "new config has no profiles")
EndProcedure

Procedure TestBuildLaunch()
  Define.s json$, doomPath$, modPath$, debPath$, joined$
  doomPath$ = TempFile("DOOM.WAD")
  modPath$ = TempFile("mod.pk3")
  debPath$ = TempFile("patch.deh")
  WriteFixture("DOOM.WAD", "x")
  WriteFixture("mod.pk3", "x")
  WriteFixture("patch.deh", "x")
  json$ = "{" + Quote("source_ports") + ": [{" + Quote("name") + ": " + Quote("Echo") + ", " + Quote("executable") + ": " + Q("C:\Windows\System32\hostname.exe") + "}], " + Quote("iwads") + ": [{" + Quote("name") + ": " + Quote("Doom") + ", " + Quote("file") + ": " + Q(doomPath$) + "}], " + Quote("profiles") + ": [{" + Quote("name") + ": " + Quote("Test") + ", " + Quote("port") + ": " + Quote("Echo") + ", " + Quote("iwad") + ": " + Quote("Doom") + ", " + Quote("files") + ": [" + Q(modPath$) + ", " + Q(debPath$) + "], " + Quote("args") + ": " + Quote("-name " + Chr(92) + Chr(34) + "my name" + Chr(92) + Chr(34) + " -skill 4") + "}], " + Quote("settings") + ": {" + Quote("profile_saves") + ": true}}"
  WriteFixture("launch.json", json$)
  Check(LoadConfig(TempFile("launch.json")), "launch fixture loads: " + LastError$)
  Define *p.Profile = FindProfilePtr("Test")
  Check(BuildLaunch(*p), "launch builds: " + LastError$)
  joined$ = JoinArgs()
  Check(Bool(FindString(joined$, "|-iwad|" + doomPath$ + "|") > 0), "launch includes the IWAD")
  Check(Bool(FindString(joined$, "|-file|" + modPath$ + "|") > 0), "launch includes mods with -file")
  Check(Bool(FindString(joined$, "|-deh|" + debPath$ + "|") > 0), "launch passes .deh with -deh")
  Check(Bool(FindString(joined$, "|my name|") > 0 And FindString(joined$, "|-skill|4|") > 0), "launch keeps quoted extra arguments")
  Check(Bool(FindString(joined$, "|-config|") > 0), "profile config is isolated by default")
  Check(Bool(FindString(joined$, "|-savedir|") > 0), "profile saves are isolated when enabled")
  Check(Bool(FindString(SpecLog$, "launch.log") > 0), "launch log lives in the profile folder")
  CheckEqual(SpecExe$, "C:\Windows\System32\hostname.exe", "executable path is kept")
  CheckEqual(SpecCwd$, "C:\Windows\System32", "working directory defaults to the executable folder")

  *p\Args$ = "-config other.ini"
  Check(BuildLaunch(*p), "user -config is accepted")
  joined$ = JoinArgs()
  Check(Bool(CountString(joined$, "-config") = 1), "user -config suppresses the isolated config")
  Check(Bool(SpecConfig$ = ""), "suppressed config is not seeded")

  *p\Args$ = ""
  *p\IsolateConfig = #Tri_No
  Check(BuildLaunch(*p), "isolation can be turned off per profile")
  Check(Bool(FindString(JoinArgs(), "|-config|") = 0), "per-profile isolation off removes -config")
EndProcedure

Procedure TestDisabledAndMissing()
  Define *p.Profile = FindProfilePtr("Test")
  Define *file.ProfileFile
  Define.i index
  For index = 0 To ProfileFileCount(*p\ID) - 1
    *file = ProfileFilePtr(*p\ID, index)
    *file\Enabled = #False
  Next
  Check(BuildLaunch(*p), "disabled mods are skipped")
  Check(Bool(FindString(JoinArgs(), "|-file|") = 0 And FindString(JoinArgs(), "|-deh|") = 0), "no mod flags when all mods are disabled")
  *file = ProfileFilePtr(*p\ID, 0)
  *file\Enabled = #True
  *file\Path$ = TempFile("does-not-exist.pk3")
  Check(Not BuildLaunch(*p), "a missing enabled mod is reported")
  CheckEqual(LastError$, "Mod file not found: " + TempFile("does-not-exist.pk3"), "missing mod message")
EndProcedure

Procedure TestRenameAndFolders()
  Define *p.Profile
  Define.i id
  ResetModel()
  AddPortEntry("Echo", TempFile("DOOM.WAD"))
  AddIwadEntry("Doom", TempFile("DOOM.WAD"))
  id = AddProfileEntry("Test", "Echo", "Doom")
  Check(Bool(id <> 0), "profile is added")
  *p = FindProfilePtr("Test")
  CheckEqual(ProfileFolderName(*p), "Test", "new profile folder matches its name")
  Check(RenameProfileEntry("Test", "Renamed"), "rename succeeds")
  *p = FindProfilePtr("Renamed")
  CheckEqual(ProfileFolderName(*p), "Test", "rename keeps the original folder")
  AddProfileEntry("Test", "Echo", "Doom")
  *p = FindProfilePtr("Test")
  CheckEqual(ProfileFolderName(*p), "Test 2", "new profile avoids folder collisions")
  Check(Not RenameProfileEntry("Renamed", "Test"), "rename to an existing name is refused")
  CheckEqual(LastError$, "A profile named 'Test' already exists.", "duplicate rename message")
EndProcedure

Procedure TestRoundTripAndZdl()
  Define *p.Profile
  Define *file.ProfileFile
  Define.i id
  Define.s text$
  ResetModel()
  AddPortEntry("Echo", TempFile("DOOM.WAD"))
  AddIwadEntry("Doom", TempFile("DOOM.WAD"))
  id = AddProfileEntry("One", "Echo", "Doom", "-skill 4")
  AddProfileFile(id, TempFile("mod.pk3"), #False)
  AddProfileFile(id, TempFile("DOOM.WAD"), #True)
  SetConfigPath(TempFile("roundtrip.json"))
  Check(WriteConfig(), "config writes")
  Check(LoadConfig(TempFile("roundtrip.json")), "config reloads")
  *p = FindProfilePtr("One")
  Check(Bool(*p <> 0), "profile survives a round trip")
  If *p
    CheckEqual(*p\Args$, "-skill 4", "args survive a round trip")
    Check(Bool(ProfileFileCount(*p\ID) = 2), "files survive a round trip")
    *file = ProfileFilePtr(*p\ID, 0)
    Check(Bool(*file\Enabled = #False), "disabled mod state survives a round trip")
  EndIf

  text$ = ProfileZdlText(*p)
  Check(Bool(FindString(text$, "[zdl.save]") = 1), "zdl export starts with [zdl.save]")
  Check(Bool(FindString(text$, "file0 = " + TempFile("DOOM.WAD")) > 0), "zdl export writes enabled files only")
  Check(Bool(FindString(text$, "file1 =") = 0), "zdl export does not number disabled files")

  Check(LoadZdlProfileText(text$, "Exported"), "zdl profile loads back: " + LastError$)
  CheckEqual(ZdlProfile\PortName$, "Echo", "zdl port round trip")
  CheckEqual(ZdlProfile\Args$, "-skill 4", "zdl extra round trip")
  Check(Bool(ProfileFileCount(#ZDL_Profile_ID) = 1), "zdl keeps only the enabled file")
  ClearZdlProfile()

  Check(LoadZdlText(AppZdlText()), "app zdl text parses")
  Check(Bool(FindPortPtr("Echo") <> 0 And FindIwadPtr("Doom") <> 0), "app zdl text keeps ports and IWADs")
EndProcedure

Procedure TestPortsScan()
  Define.s root$ = TempFile("scan")
  Define.s currentGz$ = PathJoin(root$, "scoop\apps\gzdoom\current\gzdoom.exe")
  WriteFixture("scan\scoop\apps\crispy-doom\current\crispy-doom.exe", "")
  WriteFixture("scan\scoop\apps\gzdoom\4.14.2\gzdoom.exe", "")
  WriteFixture("scan\scoop\apps\gzdoom\current\gzdoom.exe", "")
  WriteFixture("scan\a\b\c\d\woof.exe", "")
  WriteFixture("scan\notes.exe", "")

  ClearList(ScanRoots())
  AddElement(ScanRoots())
  ScanRoots() = PathJoin(root$, "scoop\apps")
  ScanForPorts(3)
  Check(Bool(ListSize(Found()) = 2), "scan finds one GZDoom and one Crispy Doom")
  Define.s gzPath$ = ""
  ForEach Found()
    If Found()\Name$ = "GZDoom"
      gzPath$ = Found()\Path$
    EndIf
  Next
  CheckEqual(gzPath$, currentGz$, "scoop versioned installs resolve to current")

  ClearList(ScanRoots())
  AddElement(ScanRoots())
  ScanRoots() = PathJoin(root$, "a")
  ScanForPorts(2)
  Check(Bool(ListSize(Found()) = 0), "scan respects the depth limit")
  ScanForPorts(5)
  Check(Bool(ListSize(Found()) = 1), "scan finds ports within the depth limit")
EndProcedure

Procedure TestAtomicWrite()
  Define.s path$ = TempFile("atomic.json")
  Define.i count = 0, dirId
  Check(WriteTextFileAtomic(path$, "one"), "first atomic write succeeds")
  Check(WriteTextFileAtomic(path$, "two"), "atomic write replaces an existing file")
  CheckEqual(ReadTextFile(path$), "two", "atomic write leaves the new contents")
  dirId = ExamineDirectory(#PB_Any, TestRoot$, "*.tmp")
  If dirId
    While NextDirectoryEntry(dirId)
      count + 1
    Wend
    FinishDirectory(dirId)
  EndIf
  Check(Bool(count = 0), "atomic write leaves no temp files behind")
EndProcedure

OpenConsole()
TestRoot$ = PathJoin(GetEnvironmentVariable("TEMP"), "pyzdl-tests-" + Str(Random(999999999)))
EnsureDir(TestRoot$)

TestJson()
TestPaths()
TestCommandLine()
TestSplitArgs()
TestConfigListForm()
TestConfigMapForm()
TestConfigErrors()
TestDefaultsAndSettings()
TestBuildLaunch()
TestDisabledAndMissing()
TestRenameAndFolders()
TestRoundTripAndZdl()
TestPortsScan()
TestAtomicWrite()

PrintN("Checks run: " + Str(TestCount) + "  failed: " + Str(TestFailed))
If TestFailed > 0
  End 1
EndIf
End 0
