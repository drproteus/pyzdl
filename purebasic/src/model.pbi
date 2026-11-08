; Configuration model: source ports, IWADs, profiles, settings, and their
; JSON and ZDL representations. Mirrors lib/config.py, lib/models.py, and the
; LoaderApp operations used by the Python launcher.

#Tri_Default = -1
#Tri_No = 0
#Tri_Yes = 1
#ZDL_Profile_ID = -1

Structure NamedPath
  Name$
  Path$
EndStructure

Structure Profile
  ID.i
  Name$
  Folder$
  PortName$
  IwadName$
  Args$
  Image$
  CfgPath$
  SavePath$
  WorkDir$
  IsolateConfig.i
  IsolateSaves.i
EndStructure

; Mod files for a profile. Files are kept in one list and grouped by ProfileID so
; that structures stay free of nested lists.
Structure ProfileFile
  ProfileID.i
  Path$
  Enabled.i
EndStructure

Global NewList Ports.NamedPath()
Global NewList Iwads.NamedPath()
Global NewList Profiles.Profile()
Global NewList ProfileFiles.ProfileFile()

Global NextProfileID.i = 1
Global ConfigPath$
Global PyzdlRoot$
Global SettingProfileConfigs.i = #True
Global SettingProfileSaves.i = #False
Global SettingDoomWadDir$
Global SettingDoomWadPath$
Global SettingDefaultConfig$
Global UiHasGeometry.i
Global UiX.i, UiY.i, UiW.i, UiH.i
Global UiSelected$
Global UiHasSash.i
Global UiSash.i

Global ZdlProfile.Profile

Procedure.s DefaultRoot()
  Define.s root$ = GetEnvironmentVariable("PYZDL_ROOT")
  If root$ <> ""
    ProcedureReturn root$
  EndIf
  ProcedureReturn ExeDir()
EndProcedure

Procedure.s DefaultConfigPath()
  Define.s path$ = GetEnvironmentVariable("PYZDL_CONFIG_PATH")
  If path$ <> ""
    ProcedureReturn path$
  EndIf
  ProcedureReturn PathJoin(DefaultRoot(), "config.json")
EndProcedure

Procedure SetConfigPath(path$)
  ConfigPath$ = AbsPath(path$)
  PyzdlRoot$ = DirName(ConfigPath$)
  If PyzdlRoot$ = ""
    PyzdlRoot$ = DefaultRoot()
  EndIf
EndProcedure

Procedure ResetModel()
  ClearList(Ports())
  ClearList(Iwads())
  ClearList(Profiles())
  ClearList(ProfileFiles())
  NextProfileID = 1
  SettingProfileConfigs = #True
  SettingProfileSaves = #False
  SettingDoomWadDir$ = ""
  SettingDoomWadPath$ = ""
  SettingDefaultConfig$ = ""
  UiHasGeometry = #False
  UiX = 0
  UiY = 0
  UiW = 0
  UiH = 0
  UiSelected$ = ""
  UiHasSash = #False
  UiSash = 0
EndProcedure

Procedure.s SafeFolder(name$)
  Define.s out$ = "", c$
  Define.i i
  name$ = ReplaceString(ReplaceString(name$, "/", "_"), "\", "_")
  For i = 1 To Len(name$)
    c$ = Mid(name$, i, 1)
    If FindString("<>:" + Chr(34) + "|?*", c$, 1)
      out$ + "_"
    Else
      out$ + c$
    EndIf
  Next
  ProcedureReturn out$
EndProcedure

Procedure.s ProfileFolderName(*p.Profile)
  If *p\Folder$ <> ""
    ProcedureReturn SafeFolder(*p\Folder$)
  EndIf
  ProcedureReturn SafeFolder(*p\Name$)
EndProcedure

Procedure.s ProfileDirPath(*p.Profile)
  ProcedureReturn PathJoin(PathJoin(PyzdlRoot$, "profiles"), ProfileFolderName(*p))
EndProcedure

Procedure.s ProfileSavePath(*p.Profile)
  If *p\SavePath$ <> ""
    ProcedureReturn ExpandPath(*p\SavePath$, PyzdlRoot$)
  EndIf
  ProcedureReturn PathJoin(ProfileDirPath(*p), "saves")
EndProcedure

Procedure.s ProfileDefaultConfig(*p.Profile)
  ProcedureReturn PathJoin(ProfileDirPath(*p), "gzdoom.ini")
EndProcedure

Procedure.s ProfileCoverArt(*p.Profile)
  Define.s names$ = "cover.jpg|cover.png|cover.jpeg|cover.webp"
  Define.s candidate$
  Define.i i, count = CountString(names$, "|") + 1
  For i = 1 To count
    candidate$ = PathJoin(ProfileDirPath(*p), StringField(names$, i, "|"))
    If IsFilePath(candidate$)
      ProcedureReturn candidate$
    EndIf
  Next
  ProcedureReturn ""
EndProcedure

Procedure.s DoomWadDir()
  Define.s value$
  If SettingDoomWadDir$ <> ""
    value$ = ExpandPath(SettingDoomWadDir$, PyzdlRoot$)
    If value$ <> ""
      ProcedureReturn value$
    EndIf
  EndIf
  value$ = ExpandPath(GetEnvironmentVariable("DOOMWADDIR"), PyzdlRoot$)
  If value$ <> ""
    ProcedureReturn value$
  EndIf
  ProcedureReturn PyzdlRoot$
EndProcedure

; DOOMWADPATH as a ';'-separated list. Empty entries are dropped.
Procedure.s DoomWadPathValue()
  Define.s out$ = "", part$, raw$
  Define.i i, count
  If SettingDoomWadPath$ <> ""
    raw$ = SettingDoomWadPath$
    count = CountString(raw$, ";") + 1
    For i = 1 To count
      part$ = ExpandPath(StringField(raw$, i, ";"), PyzdlRoot$)
      If part$ <> ""
        If out$ <> ""
          out$ + ";"
        EndIf
        out$ + part$
      EndIf
    Next
    ProcedureReturn out$
  EndIf
  raw$ = GetEnvironmentVariable("DOOMWADPATH")
  count = CountString(raw$, ";") + 1
  For i = 1 To count
    part$ = StringField(raw$, i, ";")
    If part$ <> ""
      If out$ <> ""
        out$ + ";"
      EndIf
      out$ + part$
    EndIf
  Next
  ProcedureReturn out$
EndProcedure

Procedure.s DefaultGzConfig()
  Define.s relative$ = SettingDefaultConfig$
  If relative$ = ""
    relative$ = PathJoin("defaults", "gzdoom.ini")
  EndIf
  ProcedureReturn ExpandPath(relative$, PyzdlRoot$)
EndProcedure

Procedure.i FindPortPtr(name$)
  ForEach Ports()
    If Ports()\Name$ = name$
      ProcedureReturn @Ports()
    EndIf
  Next
  ProcedureReturn 0
EndProcedure

Procedure.i FindIwadPtr(name$)
  ForEach Iwads()
    If Iwads()\Name$ = name$
      ProcedureReturn @Iwads()
    EndIf
  Next
  ProcedureReturn 0
EndProcedure

Procedure.i FindProfilePtr(name$)
  ForEach Profiles()
    If Profiles()\Name$ = name$
      ProcedureReturn @Profiles()
    EndIf
  Next
  ProcedureReturn 0
EndProcedure

Procedure.i FindProfileByID(id.i)
  ForEach Profiles()
    If Profiles()\ID = id
      ProcedureReturn @Profiles()
    EndIf
  Next
  ProcedureReturn 0
EndProcedure

Procedure.i ProfileFileCount(id.i)
  Define.i count = 0
  ForEach ProfileFiles()
    If ProfileFiles()\ProfileID = id
      count + 1
    EndIf
  Next
  ProcedureReturn count
EndProcedure

Procedure.i ProfileFilePtr(id.i, index.i)
  Define.i seen = 0
  ForEach ProfileFiles()
    If ProfileFiles()\ProfileID = id
      If seen = index
        ProcedureReturn @ProfileFiles()
      EndIf
      seen + 1
    EndIf
  Next
  ProcedureReturn 0
EndProcedure

Procedure AddProfileFile(id.i, path$, enabled.i = #True)
  LastElement(ProfileFiles()) : AddElement(ProfileFiles())
  ProfileFiles()\ProfileID = id
  ProfileFiles()\Path$ = path$
  ProfileFiles()\Enabled = Bool(enabled <> 0)
EndProcedure

Procedure RemoveProfileFiles(id.i)
  ForEach ProfileFiles()
    If ProfileFiles()\ProfileID = id
      DeleteElement(ProfileFiles())
    EndIf
  Next
EndProcedure

Procedure.s UsingPort(name$)
  Define.s out$ = ""
  ForEach Profiles()
    If Profiles()\PortName$ = name$
      If out$ <> ""
        out$ + ", "
      EndIf
      out$ + Profiles()\Name$
    EndIf
  Next
  ProcedureReturn out$
EndProcedure

Procedure.s UsingIwad(name$)
  Define.s out$ = ""
  ForEach Profiles()
    If Profiles()\IwadName$ = name$
      If out$ <> ""
        out$ + ", "
      EndIf
      out$ + Profiles()\Name$
    EndIf
  Next
  ProcedureReturn out$
EndProcedure

Procedure.b FolderInUse(folder$, excludeID.i)
  ForEach Profiles()
    If Profiles()\ID <> excludeID And ProfileFolderName(@Profiles()) = folder$
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure.s UniqueFolder(name$, excludeID.i = 0)
  Define.s base$ = SafeFolder(name$)
  Define.s candidate$ = base$
  Define.i counter = 2
  While FolderInUse(candidate$, excludeID)
    candidate$ = base$ + " " + Str(counter)
    counter + 1
  Wend
  ProcedureReturn candidate$
EndProcedure

Procedure.b AddPortEntry(name$, path$)
  Define.i ptr
  If Not PathExists(ExpandPath(path$, PyzdlRoot$))
    ProcedureReturn Fail(path$ + " does not exist.")
  EndIf
  ptr = FindPortPtr(name$)
  If ptr
    Define *Port.NamedPath : *Port = ptr
    *Port\Path$ = path$
  Else
    LastElement(Ports()) : AddElement(Ports())
    Ports()\Name$ = name$
    Ports()\Path$ = path$
  EndIf
  ProcedureReturn #True
EndProcedure

Procedure.b RemovePortEntry(name$)
  Define.s users$ = UsingPort(name$)
  If users$ <> ""
    ProcedureReturn Fail("Cannot remove source port '" + name$ + "'; it is used by: " + users$)
  EndIf
  ForEach Ports()
    If Ports()\Name$ = name$
      DeleteElement(Ports())
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure.b AddIwadEntry(name$, path$)
  Define.i ptr
  If Not PathExists(ExpandPath(path$, PyzdlRoot$))
    ProcedureReturn Fail(path$ + " does not exist.")
  EndIf
  ptr = FindIwadPtr(name$)
  If ptr
    Define *Iwad.NamedPath : *Iwad = ptr
    *Iwad\Path$ = path$
  Else
    LastElement(Iwads()) : AddElement(Iwads())
    Iwads()\Name$ = name$
    Iwads()\Path$ = path$
  EndIf
  ProcedureReturn #True
EndProcedure

Procedure.b RemoveIwadEntry(name$)
  Define.s users$ = UsingIwad(name$)
  If users$ <> ""
    ProcedureReturn Fail("Cannot remove IWAD '" + name$ + "'; it is used by: " + users$)
  EndIf
  ForEach Iwads()
    If Iwads()\Name$ = name$
      DeleteElement(Iwads())
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

; Appends a profile with no files. Returns its ID, or 0 with LastError$ set.
Procedure.i AddProfileEntry(name$, portName$, iwadName$, args$ = "")
  Define.s folder$
  If FindProfilePtr(name$)
    Fail("A profile named '" + name$ + "' already exists.")
    ProcedureReturn 0
  EndIf
  If FindPortPtr(portName$) = 0
    Fail("Unknown source port '" + portName$ + "'.")
    ProcedureReturn 0
  EndIf
  If FindIwadPtr(iwadName$) = 0
    Fail("Unknown IWAD '" + iwadName$ + "'.")
    ProcedureReturn 0
  EndIf
  folder$ = UniqueFolder(name$)
  LastElement(Profiles()) : AddElement(Profiles())
  Profiles()\ID = NextProfileID
  NextProfileID + 1
  Profiles()\Name$ = name$
  Profiles()\Folder$ = folder$
  Profiles()\PortName$ = portName$
  Profiles()\IwadName$ = iwadName$
  Profiles()\Args$ = args$
  Profiles()\IsolateConfig = #Tri_Default
  Profiles()\IsolateSaves = #Tri_Default
  ProcedureReturn Profiles()\ID
EndProcedure

Procedure.b RemoveProfileEntry(name$)
  ForEach Profiles()
    If Profiles()\Name$ = name$
      RemoveProfileFiles(Profiles()\ID)
      DeleteElement(Profiles())
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure.b RenameProfileEntry(oldName$, newName$)
  Define.i ptr
  If oldName$ = newName$
    ProcedureReturn #True
  EndIf
  If FindProfilePtr(newName$)
    ProcedureReturn Fail("A profile named '" + newName$ + "' already exists.")
  EndIf
  ptr = FindProfilePtr(oldName$)
  If ptr = 0
    ProcedureReturn Fail("Unknown profile '" + oldName$ + "'.")
  EndIf
  Define *p.Profile : *p = ptr
  If *p\Folder$ = ""
    *p\Folder$ = SafeFolder(oldName$)
  EndIf
  *p\Name$ = newName$
  ProcedureReturn #True
EndProcedure

Procedure.s ResourcePath(obj.i, key$)
  Define.i child = JGet(obj, key$)
  If child = 0
    ProcedureReturn ""
  EndIf
  If JN(child)\Kind = #JSON_String
    ProcedureReturn JN(child)\Text$
  EndIf
  If JN(child)\Kind = #JSON_Object
    ProcedureReturn JStr(child, "path", "")
  EndIf
  ProcedureReturn ""
EndProcedure

Procedure.i TriState(obj.i, key$)
  Define.i child = JGet(obj, key$)
  If child And JN(child)\Kind = #JSON_Bool
    ProcedureReturn JN(child)\Flag
  EndIf
  ProcedureReturn #Tri_Default
EndProcedure

; Ports, IWADs, and profiles may be JSON arrays or name-keyed objects. These
; helpers walk either shape in order.
Procedure.i NamedItemCount(list.i)
  Define.i count = 0, child
  If list = 0
    ProcedureReturn 0
  EndIf
  child = JN(list)\FirstChild
  While child
    count + 1
    child = JN(child)\NextSibling
  Wend
  ProcedureReturn count
EndProcedure

Procedure.i NamedItemAt(list.i, index.i)
  Define.i child = JN(list)\FirstChild, seen = 0
  While child
    If seen = index
      ProcedureReturn child
    EndIf
    seen + 1
    child = JN(child)\NextSibling
  Wend
  ProcedureReturn 0
EndProcedure

Procedure.s NamedItemName(item.i, index.i)
  Define.s name$ = JStr(item, "name", "")
  If name$ = "" And JN(item)\Key$ <> ""
    ProcedureReturn JN(item)\Key$
  EndIf
  ProcedureReturn name$
EndProcedure

; Reads the JSON config. Accepts list or name-keyed forms for ports, IWADs, and
; profiles, and missing settings fall back to the Python defaults.
Procedure.b LoadAppJson(root.i)
  Define.i settings, vars, ui, geometry, list, index, count, item, child, files, fileNode, names
  Define.s name$, path$, portName$, iwadName$, wadPath$
  Define.i portCount, iwadCount, profileCount

  settings = JGet(root, "settings")
  SettingProfileSaves = JBool(settings, "profile_saves", #False)
  SettingProfileConfigs = JBool(settings, "profile_configs", #True)
  SettingDefaultConfig$ = JStr(settings, "default_config", "")
  vars = JGet(settings, "vars")
  SettingDoomWadDir$ = JStr(vars, "doomwaddir", "")
  SettingDoomWadPath$ = ""
  child = JGet(vars, "doomwadpath")
  If child
    If JN(child)\Kind = #JSON_String
      SettingDoomWadPath$ = JN(child)\Text$
    ElseIf JN(child)\Kind = #JSON_Array
      item = JN(child)\FirstChild
      While item
        If JN(item)\Kind = #JSON_String And JN(item)\Text$ <> ""
          If SettingDoomWadPath$ <> ""
            SettingDoomWadPath$ + ";"
          EndIf
          SettingDoomWadPath$ + JN(item)\Text$
        EndIf
        item = JN(item)\NextSibling
      Wend
    EndIf
  EndIf

  ui = JGet(settings, "ui")
  geometry = JGet(ui, "geometry")
  If geometry And JN(geometry)\Kind = #JSON_Array And NamedItemCount(geometry) = 4
    UiHasGeometry = #True
    UiX = Val(JN(NamedItemAt(geometry, 0))\Text$)
    UiY = Val(JN(NamedItemAt(geometry, 1))\Text$)
    UiW = Val(JN(NamedItemAt(geometry, 2))\Text$)
    UiH = Val(JN(NamedItemAt(geometry, 3))\Text$)
  EndIf
  UiSelected$ = JStr(ui, "selected_profile", "")
  If JInt(ui, "sash", -1) >= 0
    UiHasSash = #True
    UiSash = JInt(ui, "sash", 0)
  EndIf

  list = JGet(root, "source_ports")
  count = NamedItemCount(list)
  For index = 0 To count - 1
    item = NamedItemAt(list, index)
    name$ = NamedItemName(item, index)
    child = JGet(item, "executable")
    path$ = ""
    If child And JN(child)\Kind = #JSON_String
      path$ = JN(child)\Text$
    ElseIf child And JN(child)\Kind = #JSON_Object
      path$ = JStr(child, "path", "")
    EndIf
    If name$ = "" Or path$ = ""
      ProcedureReturn Fail("Source port is missing an executable path.")
    EndIf
    If FindPortPtr(name$)
      ProcedureReturn Fail("Duplicate source port name: '" + name$ + "'")
    EndIf
    LastElement(Ports()) : AddElement(Ports())
    Ports()\Name$ = name$
    Ports()\Path$ = path$
  Next

  list = JGet(root, "iwads")
  count = NamedItemCount(list)
  For index = 0 To count - 1
    item = NamedItemAt(list, index)
    name$ = NamedItemName(item, index)
    path$ = ResourcePath(item, "file")
    If name$ = "" Or path$ = ""
      ProcedureReturn Fail("IWAD is missing a file path.")
    EndIf
    If FindIwadPtr(name$)
      ProcedureReturn Fail("Duplicate IWAD name: '" + name$ + "'")
    EndIf
    LastElement(Iwads()) : AddElement(Iwads())
    Iwads()\Name$ = name$
    Iwads()\Path$ = path$
  Next

  list = JGet(root, "profiles")
  count = NamedItemCount(list)
  For index = 0 To count - 1
    item = NamedItemAt(list, index)
    name$ = NamedItemName(item, index)
    If name$ = ""
      ProcedureReturn Fail("Profile is missing a name.")
    EndIf
    child = JGet(item, "port")
    portName$ = ""
    If child And JN(child)\Kind = #JSON_String
      portName$ = JN(child)\Text$
    ElseIf child And JN(child)\Kind = #JSON_Object
      portName$ = JStr(child, "name", "")
    EndIf
    child = JGet(item, "iwad")
    iwadName$ = ""
    If child And JN(child)\Kind = #JSON_String
      iwadName$ = JN(child)\Text$
    ElseIf child And JN(child)\Kind = #JSON_Object
      iwadName$ = JStr(child, "name", "")
    EndIf
    If FindPortPtr(portName$) = 0
      ProcedureReturn Fail("Profile '" + name$ + "' references unknown source port '" + portName$ + "'.")
    EndIf
    If FindIwadPtr(iwadName$) = 0
      ProcedureReturn Fail("Profile '" + name$ + "' references unknown IWAD '" + iwadName$ + "'.")
    EndIf
    If FindProfilePtr(name$)
      ProcedureReturn Fail("Duplicate profile name: '" + name$ + "'")
    EndIf
    LastElement(Profiles()) : AddElement(Profiles())
    Profiles()\ID = NextProfileID
    NextProfileID + 1
    Profiles()\Name$ = name$
    Profiles()\PortName$ = portName$
    Profiles()\IwadName$ = iwadName$
    Profiles()\Args$ = JStr(item, "args", "")
    Profiles()\Image$ = ResourcePath(item, "image")
    Profiles()\CfgPath$ = ResourcePath(item, "config")
    Profiles()\SavePath$ = ResourcePath(item, "savedir")
    Profiles()\WorkDir$ = ResourcePath(item, "workdir")
    Profiles()\IsolateConfig = TriState(item, "isolate_config")
    Profiles()\IsolateSaves = TriState(item, "isolate_saves")
    Profiles()\Folder$ = JStr(item, "folder", SafeFolder(name$))
    files = JGet(item, "files")
    If files And JN(files)\Kind = #JSON_Array
      fileNode = JN(files)\FirstChild
      While fileNode
        If JN(fileNode)\Kind = #JSON_String
          AddProfileFile(Profiles()\ID, JN(fileNode)\Text$, #True)
        ElseIf JN(fileNode)\Kind = #JSON_Object
          path$ = JStr(fileNode, "path", "")
          If path$ = ""
            ProcedureReturn Fail("Resource is missing a path.")
          EndIf
          AddProfileFile(Profiles()\ID, path$, JBool(fileNode, "enabled", #True))
        EndIf
        fileNode = JN(fileNode)\NextSibling
      Wend
    EndIf
  Next
  ProcedureReturn #True
EndProcedure

; Reads [zdl.ports] and [zdl.iwads] into the source port and IWAD lists.
Procedure.b LoadZdlText(text$)
  Define.s name$, path$
  Define.i index, ptr
  ParseIniText(text$)
  If Not IniHasSection("zdl.ports") Or Not IniHasSection("zdl.iwads")
    ProcedureReturn Fail("ZDL config must contain [zdl.ports] and [zdl.iwads] sections.")
  EndIf
  ForEach IniEntries()
    If IniEntries()\Section$ = "zdl.ports"
      index = IniIndexKey(IniEntries()\Key$, "p", "n")
      If index >= 0
        name$ = IniEntries()\Value$
        path$ = IniGet("zdl.ports", "p" + Str(index) + "f", "")
        ptr = FindPortPtr(name$)
        If ptr = 0
          LastElement(Ports()) : AddElement(Ports())
          Ports()\Name$ = name$
          Ports()\Path$ = path$
        Else
          Define *Port.NamedPath : *Port = ptr
          *Port\Path$ = path$
        EndIf
      EndIf
    EndIf
  Next
  ForEach IniEntries()
    If IniEntries()\Section$ = "zdl.iwads"
      index = IniIndexKey(IniEntries()\Key$, "i", "n")
      If index >= 0
        name$ = IniEntries()\Value$
        path$ = IniGet("zdl.iwads", "i" + Str(index) + "f", "")
        ptr = FindIwadPtr(name$)
        If ptr = 0
          LastElement(Iwads()) : AddElement(Iwads())
          Iwads()\Name$ = name$
          Iwads()\Path$ = path$
        Else
          Define *Iwad.NamedPath : *Iwad = ptr
          *Iwad\Path$ = path$
        EndIf
      EndIf
    EndIf
  Next
  ProcedureReturn #True
EndProcedure

Procedure.b LoadConfig(path$)
  Define.s text$, name$
  Define.i root
  ResetModel()
  SetConfigPath(path$)
  If Not PathExists(ConfigPath$)
    SettingProfileSaves = #True
    SettingProfileConfigs = #True
    ProcedureReturn #True
  EndIf
  If ExtLower(ConfigPath$) = ".json"
    text$ = ReadTextFile(ConfigPath$)
    root = JParse(text$)
    If root = 0
      ProcedureReturn Fail("Could not read config " + ConfigPath$ + ": " + JError$)
    EndIf
    If JN(root)\Kind <> #JSON_Object
      ProcedureReturn Fail("Config must be a JSON object: " + ConfigPath$)
    EndIf
    If Not LoadAppJson(root)
      ProcedureReturn #False
    EndIf
    ProcedureReturn #True
  EndIf
  If ExtLower(ConfigPath$) = ".zdl" Or ExtLower(ConfigPath$) = ".ini"
    ProcedureReturn LoadZdlText(ReadTextFile(ConfigPath$))
  EndIf
  ProcedureReturn Fail("Unknown config format: " + ConfigPath$)
EndProcedure

Procedure.b ResourceNode(parent.i, key$, path$)
  If path$ = ""
    JAddNull(parent, key$)
  Else
    JAddString(parent, key$, path$)
  EndIf
  ProcedureReturn #True
EndProcedure

; nested=#True writes port and IWAD as objects (profile inspect output).
; nested=#False writes them as names (config file format).
Procedure.i ProfileNode(*p.Profile, root.i, nested.b)
  Define.i node, files, index, fileIndex, portPtr, iwadPtr, obj, tmp, wad, arr
  Define.s wadPath$
  node = JAddObject(root, "")
  JAddString(node, "name", *p\Name$)
  portPtr = FindPortPtr(*p\PortName$)
  If nested And portPtr
    Define *port.NamedPath : *port = portPtr
    obj = JAddObject(node, "port")
    JAddString(obj, "name", *port\Name$)
    JAddString(obj, "executable", *port\Path$)
  Else
    JAddString(node, "port", *p\PortName$)
  EndIf
  iwadPtr = FindIwadPtr(*p\IwadName$)
  If nested And iwadPtr
    Define *iwad.NamedPath : *iwad = iwadPtr
    obj = JAddObject(node, "iwad")
    JAddString(obj, "name", *iwad\Name$)
    JAddString(obj, "file", *iwad\Path$)
  Else
    JAddString(node, "iwad", *p\IwadName$)
  EndIf
  files = JAddArray(node, "files")
  For index = 0 To ProfileFileCount(*p\ID) - 1
    Define *file.ProfileFile : *file = ProfileFilePtr(*p\ID, index)
    If *file\Enabled
      JAddString(files, "", *file\Path$)
    Else
      obj = JAddObject(files, "")
      JAddString(obj, "path", *file\Path$)
      JAddBool(obj, "enabled", #False)
    EndIf
  Next
  JAddString(node, "args", *p\Args$)
  ResourceNode(node, "image", *p\Image$)
  ResourceNode(node, "config", *p\CfgPath$)
  ResourceNode(node, "savedir", *p\SavePath$)
  ResourceNode(node, "workdir", *p\WorkDir$)
  If *p\IsolateConfig = #Tri_Default
    JAddNull(node, "isolate_config")
  Else
    JAddBool(node, "isolate_config", *p\IsolateConfig)
  EndIf
  If *p\IsolateSaves = #Tri_Default
    JAddNull(node, "isolate_saves")
  Else
    JAddBool(node, "isolate_saves", *p\IsolateSaves)
  EndIf
  JAddString(node, "folder", *p\Folder$)
  ProcedureReturn node
EndProcedure

Procedure.s ConfigJsonText()
  Define.i root, arr, obj, settings, vars, ui, geometry, wadArr, profile
  Define.s wadPath$, part$
  Define.i i, count
  JReset()
  root = JNew(#JSON_Object)
  JAddNumber(root, "version", 2)

  arr = JAddArray(root, "source_ports")
  ForEach Ports()
    obj = JAddObject(arr, "")
    JAddString(obj, "name", Ports()\Name$)
    JAddString(obj, "executable", Ports()\Path$)
  Next

  arr = JAddArray(root, "iwads")
  ForEach Iwads()
    obj = JAddObject(arr, "")
    JAddString(obj, "name", Iwads()\Name$)
    JAddString(obj, "file", Iwads()\Path$)
  Next

  arr = JAddArray(root, "profiles")
  ForEach Profiles()
    ProfileNode(@Profiles(), arr, #False)
  Next

  settings = JAddObject(root, "settings")
  JAddString(settings, "pyzdl_root", PyzdlRoot$)
  JAddString(settings, "config_path", ConfigPath$)
  JAddBool(settings, "profile_saves", SettingProfileSaves)
  JAddBool(settings, "profile_configs", SettingProfileConfigs)
  ResourceNode(settings, "default_config", SettingDefaultConfig$)
  vars = JAddObject(settings, "vars")
  JAddString(vars, "doomwaddir", DoomWadDir())
  wadArr = JAddArray(vars, "doomwadpath")
  wadPath$ = DoomWadPathValue()
  count = CountString(wadPath$, ";") + 1
  If wadPath$ <> ""
    For i = 1 To count
      JAddString(wadArr, "", StringField(wadPath$, i, ";"))
    Next
  EndIf
  ui = JAddObject(settings, "ui")
  If UiHasGeometry
    geometry = JAddArray(ui, "geometry")
    JAddNumber(geometry, "", UiX)
    JAddNumber(geometry, "", UiY)
    JAddNumber(geometry, "", UiW)
    JAddNumber(geometry, "", UiH)
  EndIf
  If UiSelected$ <> ""
    JAddString(ui, "selected_profile", UiSelected$)
  EndIf
  If UiHasSash
    JAddNumber(ui, "sash", UiSash)
  EndIf

  ProcedureReturn JDump(root) + Chr(10)
EndProcedure

Procedure.b WriteConfig()
  ProcedureReturn WriteTextFileAtomic(ConfigPath$, ConfigJsonText())
EndProcedure

Procedure.s ProfileZdlText(*p.Profile)
  Define.s out$
  Define.i index, written = 0
  out$ = IniSectionText("zdl.save")
  out$ + "port = " + *p\PortName$ + Chr(10)
  out$ + "iwad = " + *p\IwadName$ + Chr(10)
  out$ + "extra = " + *p\Args$ + Chr(10)
  For index = 0 To ProfileFileCount(*p\ID) - 1
    Define *file.ProfileFile : *file = ProfileFilePtr(*p\ID, index)
    If *file\Enabled
      out$ + "file" + Str(written) + " = " + *file\Path$ + Chr(10)
      written + 1
    EndIf
  Next
  ProcedureReturn out$ + Chr(10)
EndProcedure

Procedure.s AppZdlText()
  Define.s out$
  Define.i index
  out$ = IniSectionText("zdl.ports")
  index = 0
  ForEach Ports()
    out$ + "p" + Str(index) + "n = " + Ports()\Name$ + Chr(10)
    out$ + "p" + Str(index) + "f = " + Ports()\Path$ + Chr(10)
    index + 1
  Next
  out$ + Chr(10) + IniSectionText("zdl.iwads")
  index = 0
  ForEach Iwads()
    out$ + "i" + Str(index) + "n = " + Iwads()\Name$ + Chr(10)
    out$ + "i" + Str(index) + "f = " + Iwads()\Path$ + Chr(10)
    index + 1
  Next
  ProcedureReturn out$ + Chr(10)
EndProcedure

Procedure.b IsFileKey(key$)
  If Left(key$, 4) = "file" And Len(key$) > 4
    ProcedureReturn Bool(FindString("0123456789", Mid(key$, 5, 1), 1) > 0)
  EndIf
  ProcedureReturn #False
EndProcedure

; Builds a profile from a [zdl.save] section into ZdlProfile, with its files stored
; under ProfileID #ZDL_Profile_ID. Callers must call ClearZdlProfile() when done.
Procedure ClearZdlProfile()
  RemoveProfileFiles(#ZDL_Profile_ID)
EndProcedure

Procedure.b LoadZdlProfileText(text$, name$)
  Define.s port$, iwad$
  ParseIniText(text$)
  If Not IniHasSection("zdl.save")
    ProcedureReturn Fail("ZDL file has no [zdl.save] section.")
  EndIf
  port$ = IniGet("zdl.save", "port", "")
  iwad$ = IniGet("zdl.save", "iwad", "")
  If port$ = "" Or iwad$ = ""
    ProcedureReturn Fail("ZDL file is missing a port or IWAD.")
  EndIf
  If FindPortPtr(port$) = 0
    ProcedureReturn Fail("ZDL file references unknown source port '" + port$ + "'.")
  EndIf
  If FindIwadPtr(iwad$) = 0
    ProcedureReturn Fail("ZDL file references unknown IWAD '" + iwad$ + "'.")
  EndIf
  ClearZdlProfile()
  ZdlProfile\ID = #ZDL_Profile_ID
  ZdlProfile\Name$ = name$
  ZdlProfile\Folder$ = ""
  ZdlProfile\PortName$ = port$
  ZdlProfile\IwadName$ = iwad$
  ZdlProfile\Args$ = IniGet("zdl.save", "extra", "")
  ZdlProfile\IsolateConfig = #Tri_Default
  ZdlProfile\IsolateSaves = #Tri_Default
  ForEach IniEntries()
    If IniEntries()\Section$ = "zdl.save" And IsFileKey(IniEntries()\Key$)
      AddProfileFile(#ZDL_Profile_ID, IniEntries()\Value$, #True)
    EndIf
  Next
  ProcedureReturn #True
EndProcedure

; Parses a profile JSON object as produced by profile inspect or the config file.
Procedure.b ImportProfileJsonText(text$, overrideName$)
  Define.i root, child, files, fileNode, id, obj
  Define.s name$, portName$, iwadName$, path$, folder$
  root = JParse(text$)
  If root = 0
    ProcedureReturn Fail("Could not read profile: " + JError$)
  EndIf
  If JN(root)\Kind <> #JSON_Object
    ProcedureReturn Fail("Profile must be a JSON object.")
  EndIf
  name$ = JStr(root, "name", "")
  If name$ = ""
    name$ = overrideName$
  EndIf
  If name$ = ""
    ProcedureReturn Fail("Profile is missing a name.")
  EndIf
  child = JGet(root, "port")
  portName$ = ""
  If child And JN(child)\Kind = #JSON_String
    portName$ = JN(child)\Text$
  ElseIf child And JN(child)\Kind = #JSON_Object
    portName$ = JStr(child, "name", "")
  EndIf
  child = JGet(root, "iwad")
  iwadName$ = ""
  If child And JN(child)\Kind = #JSON_String
    iwadName$ = JN(child)\Text$
  ElseIf child And JN(child)\Kind = #JSON_Object
    iwadName$ = JStr(child, "name", "")
  EndIf
  If FindPortPtr(portName$) = 0
    ProcedureReturn Fail("Profile references unknown source port '" + portName$ + "'.")
  EndIf
  If FindIwadPtr(iwadName$) = 0
    ProcedureReturn Fail("Profile references unknown IWAD '" + iwadName$ + "'.")
  EndIf
  If FindProfilePtr(name$)
    ProcedureReturn Fail("A profile named '" + name$ + "' already exists.")
  EndIf
  id = AddProfileEntry(name$, portName$, iwadName$, JStr(root, "args", ""))
  If id = 0
    ProcedureReturn #False
  EndIf
  Define *p.Profile : *p = FindProfileByID(id)
  *p\Image$ = ResourcePath(root, "image")
  *p\CfgPath$ = ResourcePath(root, "config")
  *p\SavePath$ = ResourcePath(root, "savedir")
  *p\WorkDir$ = ResourcePath(root, "workdir")
  *p\IsolateConfig = TriState(root, "isolate_config")
  *p\IsolateSaves = TriState(root, "isolate_saves")
  folder$ = JStr(root, "folder", "")
  If folder$ <> "" And Not FolderInUse(SafeFolder(folder$), id)
    *p\Folder$ = folder$
  EndIf
  files = JGet(root, "files")
  If files And JN(files)\Kind = #JSON_Array
    fileNode = JN(files)\FirstChild
    While fileNode
      If JN(fileNode)\Kind = #JSON_String
        AddProfileFile(id, JN(fileNode)\Text$, #True)
      ElseIf JN(fileNode)\Kind = #JSON_Object
        path$ = JStr(fileNode, "path", "")
        If path$ = ""
          ProcedureReturn Fail("Resource is missing a path.")
        EndIf
        AddProfileFile(id, path$, JBool(fileNode, "enabled", #True))
      EndIf
      fileNode = JN(fileNode)\NextSibling
    Wend
  EndIf
  ProcedureReturn #True
EndProcedure

; Imports a .json profile or a .zdl/.ini save. Name and folder collisions are
; resolved the same way as the Python importer.
Procedure.i ImportProfileFile(path$, overrideName$ = "")
  Define.s text$, name$
  Define.i id, index
  Define *p.Profile, *file.ProfileFile
  If Not IsFilePath(path$)
    Fail("ZDL file not found: " + path$)
    ProcedureReturn 0
  EndIf
  If ExtLower(path$) = ".json"
    text$ = ReadTextFile(path$)
    If Not ImportProfileJsonText(text$, overrideName$)
      ProcedureReturn 0
    EndIf
    ProcedureReturn NextProfileID - 1
  EndIf
  If ExtLower(path$) = ".zdl" Or ExtLower(path$) = ".ini"
    name$ = overrideName$
    If name$ = ""
      name$ = StemName(path$)
    EndIf
    If FindProfilePtr(name$)
      Fail("A profile named '" + name$ + "' already exists.")
      ProcedureReturn 0
    EndIf
    If Not LoadZdlProfileText(ReadTextFile(path$), name$)
      ClearZdlProfile()
      ProcedureReturn 0
    EndIf
    id = AddProfileEntry(name$, ZdlProfile\PortName$, ZdlProfile\IwadName$, ZdlProfile\Args$)
    If id
      For index = 0 To ProfileFileCount(#ZDL_Profile_ID) - 1
        *file = ProfileFilePtr(#ZDL_Profile_ID, index)
        AddProfileFile(id, *file\Path$, *file\Enabled)
      Next
    EndIf
    ClearZdlProfile()
    ProcedureReturn id
  EndIf
  Fail("Unknown file format: " + path$)
  ProcedureReturn 0
EndProcedure
