; Graphical interface: main window, profile detail editor, and dialogs. Mirrors
; wxui/main_frame.py and wxui/dialogs.py.

#WILD_MODS = "Doom mods (*.wad;*.iwad;*.pk3;*.ipk3;*.zip;*.deh;*.bex)|*.wad;*.iwad;*.pk3;*.ipk3;*.zip;*.deh;*.bex|All files (*.*)|*.*"
#WILD_IMAGES = "Images (*.png;*.jpg;*.jpeg;*.bmp)|*.png;*.jpg;*.jpeg;*.bmp|All files (*.*)|*.*"
#WILD_CONFIG = "Config files (*.ini)|*.ini|All files (*.*)|*.*"
#WILD_ZDL = "ZDL files (*.zdl;*.ini)|*.zdl;*.ini|All files (*.*)|*.*"
#WILD_PROFILES = "Profiles (*.json;*.zdl;*.ini)|*.json;*.zdl;*.ini|All files (*.*)|*.*"
#WILD_CONFIGS = "pyZDL configs (*.json;*.ini;*.zdl)|*.json;*.ini;*.zdl|All files (*.*)|*.*"

Enumeration
  #Win_Main
  #Win_NewProfile
  #Win_Resource
  #Win_Prefs
EndEnumeration

Enumeration 100
  #G_Info
  #G_SearchLabel
  #G_Search
  #G_ProfilesTitle
  #G_Count
  #G_ProfileList
  #G_BtnNew
  #G_BtnDup
  #G_BtnDel
  #G_Detail
  #G_Cover
  #G_Name
  #G_Meta
  #G_PortLabel
  #G_Port
  #G_IwadLabel
  #G_Iwad
  #G_BtnLaunch
  #G_BtnSave
  #G_BtnCover
  #G_BtnOpenFolder
  #G_LoadTitle
  #G_LoadHint
  #G_Files
  #G_BtnAddFiles
  #G_BtnAddFolder
  #G_BtnToggle
  #G_BtnRemove
  #G_BtnUp
  #G_BtnDown
  #G_BtnOpenFile
  #G_IsoFrame
  #G_CfgLabel
  #G_CfgMode
  #G_CfgPath
  #G_CfgBrowse
  #G_CfgOpen
  #G_CfgHint
  #G_SavesLabel
  #G_SavesMode
  #G_SavesPath
  #G_SavesBrowse
  #G_SavesOpen
  #G_SavesHint
  #G_WorkLabel
  #G_WorkPath
  #G_WorkBrowse
  #G_ArgsTitle
  #G_Args
  #G_PreviewTitle
  #G_Preview
EndEnumeration

Enumeration 1000
  #Menu_New
  #Menu_Open
  #Menu_Import
  #Menu_Save
  #Menu_Reload
  #Menu_OpenConfig
  #Menu_OpenConfigDir
  #Menu_OpenWadDir
  #Menu_Quit
  #Menu_Launch
  #Menu_Duplicate
  #Menu_Delete
  #Menu_OpenProfileDir
  #Menu_Prefs
  #Menu_Validate
  #Menu_About
EndEnumeration

Enumeration 2000
  #DG_NewName
  #DG_NewPort
  #DG_NewIwad
  #DG_NewCreate
  #DG_NewCancel
  #DG_ResName
  #DG_ResPath
  #DG_ResBrowse
  #DG_ResOk
  #DG_ResCancel
  #DG_PrefTabs
  #DG_PrefWadDir
  #DG_PrefWadDirBrowse
  #DG_PrefWadPath
  #DG_PrefDefaultConfig
  #DG_PrefDefaultConfigBrowse
  #DG_PrefIsoConfig
  #DG_PrefIsoSaves
  #DG_PortList
  #DG_PortAdd
  #DG_PortEdit
  #DG_PortRemove
  #DG_IwadList
  #DG_IwadAdd
  #DG_IwadEdit
  #DG_IwadRemove
  #DG_PrefOk
  #DG_PrefCancel
EndEnumeration

Structure StagedEntry
  Original$
  Name$
  Path$
EndStructure

Global NewList StagedPorts.StagedEntry()
Global NewList StagedIwads.StagedEntry()

Global CurrentName$
Global DirtyAt.i
Global DirtyDelay.i
Global CheckSyncAt.i
Global Loading.b
Global CoverImage.i
Global FontTitle.i
Global FontBold.i
Global ResultOk.b
Global ResultName$
Global ResultPath$
Global DialogPort$
Global DialogIwad$

Declare.b OpenNewProfileDialog()
Declare.b OpenPreferencesDialog()

DataSection
  CoverData:
  IncludeBinary "..\..\assets\doom-cacodemon.png"
  CoverEnd:
EndDataSection

Procedure.i ModeFromTri(tri.i)
  If tri = #Tri_Default
    ProcedureReturn 0
  EndIf
  If tri = #Tri_Yes
    ProcedureReturn 1
  EndIf
  ProcedureReturn 2
EndProcedure

Procedure.i TriFromMode(mode.i)
  If mode = 1
    ProcedureReturn #Tri_Yes
  EndIf
  If mode = 2
    ProcedureReturn #Tri_No
  EndIf
  ProcedureReturn #Tri_Default
EndProcedure

Procedure InfoMessage(message$)
  SetGadgetText(#G_Info, message$)
EndProcedure

Procedure ShowError(message$)
  MessageRequester("pyZDL", message$, #PB_MessageRequester_Error)
EndProcedure

Procedure SetStatus(message$, field.i = 0)
  StatusBarText(0, field, message$)
EndProcedure

Procedure OpenFolderInExplorer(path$)
  EnsureDir(path$)
  OpenPathInShell(path$)
EndProcedure

Procedure LoadCoverInto(*p.Profile)
  Define.s source$
  Define.i src, canvas, scale_w, scale_h, x, y
  Define.f ratio
  If IsImage(CoverImage)
    FreeImage(CoverImage)
  EndIf
  CoverImage = CreateImage(#PB_Any, 150, 190)
  src = 0
  source$ = ""
  If *p
    source$ = *p\Image$
    If source$ <> "" And Not IsFilePath(source$)
      source$ = ""
    EndIf
    If source$ = "" Or Not IsFilePath(source$)
      source$ = ProfileCoverArt(*p)
    EndIf
  EndIf
  If source$ <> ""
    src = LoadImage(#PB_Any, source$)
  EndIf
  If Not src
    src = CatchImage(#PB_Any, ?CoverData, ?CoverEnd - ?CoverData)
  EndIf
  If src And StartDrawing(ImageOutput(CoverImage))
    Box(0, 0, 150, 190, RGB(240, 240, 240))
    ratio = 150.0 / ImageWidth(src)
    If 190.0 / ImageHeight(src) < ratio
      ratio = 190.0 / ImageHeight(src)
    EndIf
    scale_w = ImageWidth(src) * ratio
    scale_h = ImageHeight(src) * ratio
    x = (150 - scale_w) / 2
    y = (190 - scale_h) / 2
    DrawingMode(#PB_2DDrawing_AlphaBlend)
    DrawImage(ImageID(src), x, y, scale_w, scale_h)
    StopDrawing()
  EndIf
  If src And IsImage(src)
    FreeImage(src)
  EndIf
  SetGadgetState(#G_Cover, ImageID(CoverImage))
EndProcedure

Procedure RefreshFiles()
  Define.i index, id, count, row
  Define.s name$
  ClearGadgetItems(#G_Files)
  If CurrentName$ = ""
    ProcedureReturn
  EndIf
  Define *p.Profile : *p = FindProfilePtr(CurrentName$)
  If *p = 0
    ProcedureReturn
  EndIf
  count = ProfileFileCount(*p\ID)
  For index = 0 To count - 1
    Define *file.ProfileFile : *file = ProfileFilePtr(*p\ID, index)
    AddGadgetItem(#G_Files, -1, "")
    row = CountGadgetItems(#G_Files) - 1
    SetGadgetItemText(#G_Files, row, BaseName(*file\Path$), 1)
    SetGadgetItemText(#G_Files, row, *file\Path$, 2)
    SetGadgetItemState(#G_Files, row, Bool(*file\Enabled) * #PB_ListIcon_Checked)
  Next
EndProcedure

Procedure.i ActiveModCount(*p.Profile)
  Define.i index, count = 0
  For index = 0 To ProfileFileCount(*p\ID) - 1
    Define *file.ProfileFile : *file = ProfileFilePtr(*p\ID, index)
    If *file\Enabled
      count + 1
    EndIf
  Next
  ProcedureReturn count
EndProcedure

Procedure UpdateDerived()
  Define.s config$, saves$, preview$
  Define.i mods
  If CurrentName$ = ""
    SetGadgetText(#G_Meta, "")
    SetGadgetText(#G_Preview, "")
    SetGadgetText(#G_CfgHint, "")
    SetGadgetText(#G_SavesHint, "")
    ProcedureReturn
  EndIf
  Define *p.Profile : *p = FindProfilePtr(CurrentName$)
  If *p = 0
    ProcedureReturn
  EndIf
  mods = ActiveModCount(*p)
  SetGadgetText(#G_Meta, *p\PortName$ + "  -  " + *p\IwadName$ + "  -  " + Str(mods) + " active mod" + Mid("s", 1, Bool(mods <> 1)))

  config$ = Trim(GetGadgetText(#G_CfgPath))
  If config$ <> ""
    SetGadgetText(#G_CfgHint, "Using custom config: " + config$)
  ElseIf (*p\IsolateConfig = #Tri_Default And SettingProfileConfigs) Or *p\IsolateConfig = #Tri_Yes
    SetGadgetText(#G_CfgHint, "Using profile config: " + ProfileDefaultConfig(*p))
  Else
    SetGadgetText(#G_CfgHint, "Using the source port's global config")
  EndIf

  saves$ = Trim(GetGadgetText(#G_SavesPath))
  If saves$ <> ""
    SetGadgetText(#G_SavesHint, "Using custom saves: " + saves$)
  ElseIf (*p\IsolateSaves = #Tri_Default And SettingProfileSaves) Or *p\IsolateSaves = #Tri_Yes
    SetGadgetText(#G_SavesHint, "Using profile saves: " + ProfileSavePath(*p))
  Else
    SetGadgetText(#G_SavesHint, "Using the source port's global save directory")
  EndIf

  If BuildLaunch(*p)
    preview$ = CommandPreview()
  Else
    preview$ = "Warning: " + LastError$
  EndIf
  SetGadgetText(#G_Preview, preview$)
EndProcedure

; Copies widget values into the model. Renaming and writing happen in SaveCurrent.
Procedure CollectCurrent()
  Define.s portName$, iwadName$
  If CurrentName$ = ""
    ProcedureReturn
  EndIf
  Define *p.Profile : *p = FindProfilePtr(CurrentName$)
  If *p = 0
    ProcedureReturn
  EndIf
  portName$ = GetGadgetText(#G_Port)
  If FindPortPtr(portName$)
    *p\PortName$ = portName$
  EndIf
  iwadName$ = GetGadgetText(#G_Iwad)
  If FindIwadPtr(iwadName$)
    *p\IwadName$ = iwadName$
  EndIf
  *p\Args$ = GetGadgetText(#G_Args)
  *p\CfgPath$ = Trim(GetGadgetText(#G_CfgPath))
  *p\SavePath$ = Trim(GetGadgetText(#G_SavesPath))
  *p\WorkDir$ = Trim(GetGadgetText(#G_WorkPath))
  *p\IsolateConfig = TriFromMode(GetGadgetState(#G_CfgMode))
  *p\IsolateSaves = TriFromMode(GetGadgetState(#G_SavesMode))
EndProcedure

Procedure MarkChanged(nameChanged.b = #False)
  If Loading Or CurrentName$ = ""
    ProcedureReturn
  EndIf
  CollectCurrent()
  UpdateDerived()
  DirtyAt = ElapsedMilliseconds()
  If nameChanged
    DirtyDelay = 1200
  Else
    DirtyDelay = 500
  EndIf
  SetStatus("Editing...")
EndProcedure

Procedure.b SaveCurrent(showErrors.b = #True)
  Define.s newName$
  Define.i ptr
  DirtyAt = 0
  If CurrentName$ = ""
    ProcedureReturn #True
  EndIf
  CollectCurrent()
  newName$ = Trim(GetGadgetText(#G_Name))
  If newName$ <> CurrentName$
    If newName$ = ""
      If showErrors
        ShowError("Profile name cannot be empty.")
      EndIf
      SetGadgetText(#G_Name, CurrentName$)
      ProcedureReturn #False
    EndIf
    If Not RenameProfileEntry(CurrentName$, newName$)
      If showErrors
        ShowError(LastError$)
      EndIf
      SetGadgetText(#G_Name, CurrentName$)
      ProcedureReturn #False
    EndIf
    CurrentName$ = newName$
    UiSelected$ = newName$
  EndIf
  If Not WriteConfig()
    SetStatus("Could not save")
    If showErrors
      ShowError(LastError$)
    EndIf
    ProcedureReturn #False
  EndIf
  Define *p.Profile : *p = FindProfilePtr(CurrentName$)
  If *p
    SetStatus("Saved")
    SetStatus(*p\PortName$ + "  -  " + *p\IwadName$, 1)
  EndIf
  ProcedureReturn #True
EndProcedure

Procedure BindDetail(name$)
  Define.i index, portIndex = 0, iwadIndex = 0, count
  Loading = #True
  CurrentName$ = name$
  Define *p.Profile : *p = FindProfilePtr(name$)
  If *p = 0
    SetGadgetText(#G_Name, "")
    ClearGadgetItems(#G_Port)
    ClearGadgetItems(#G_Iwad)
    SetGadgetText(#G_Args, "")
    SetGadgetText(#G_CfgPath, "")
    SetGadgetText(#G_SavesPath, "")
    SetGadgetText(#G_WorkPath, "")
    DisableGadget(#G_Detail, #True)
    RefreshFiles()
    LoadCoverInto(0)
    SetGadgetText(#G_Meta, "")
    SetGadgetText(#G_Preview, "")
    Loading = #False
    ProcedureReturn
  EndIf
  DisableGadget(#G_Detail, #False)
  SetGadgetText(#G_Name, *p\Name$)
  ClearGadgetItems(#G_Port)
  index = 0
  ForEach Ports()
    AddGadgetItem(#G_Port, -1, Ports()\Name$)
    If Ports()\Name$ = *p\PortName$
      portIndex = index
    EndIf
    index + 1
  Next
  SetGadgetState(#G_Port, portIndex)
  ClearGadgetItems(#G_Iwad)
  index = 0
  ForEach Iwads()
    AddGadgetItem(#G_Iwad, -1, Iwads()\Name$)
    If Iwads()\Name$ = *p\IwadName$
      iwadIndex = index
    EndIf
    index + 1
  Next
  SetGadgetState(#G_Iwad, iwadIndex)
  SetGadgetText(#G_Args, *p\Args$)
  SetGadgetState(#G_CfgMode, ModeFromTri(*p\IsolateConfig))
  SetGadgetState(#G_SavesMode, ModeFromTri(*p\IsolateSaves))
  SetGadgetText(#G_CfgPath, *p\CfgPath$)
  SetGadgetText(#G_SavesPath, *p\SavePath$)
  SetGadgetText(#G_WorkPath, *p\WorkDir$)
  LoadCoverInto(*p)
  RefreshFiles()
  UpdateDerived()
  SetStatus(*p\PortName$ + "  -  " + *p\IwadName$, 1)
  Loading = #False
EndProcedure

Procedure RefreshProfileList(selectName$ = "")
  Define.s filter$ = LCase(Trim(GetGadgetText(#G_Search)))
  Define.i index, selected = -1
  NewList Names.s()
  ForEach Profiles()
    If filter$ = "" Or FindString(LCase(Profiles()\Name$), filter$, 1)
      AddElement(Names())
      Names() = Profiles()\Name$
    EndIf
  Next
  SortList(Names(), #PB_Sort_NoCase)
  ClearGadgetItems(#G_ProfileList)
  index = 0
  ForEach Names()
    AddGadgetItem(#G_ProfileList, -1, Names())
    If Names() = selectName$
      selected = index
    EndIf
    index + 1
  Next
  SetGadgetText(#G_Count, Str(index))
  If selected < 0 And index > 0
    selected = 0
  EndIf
  If selected >= 0
    SetGadgetState(#G_ProfileList, selected)
    BindDetail(GetGadgetItemText(#G_ProfileList, selected))
  Else
    SetGadgetState(#G_ProfileList, -1)
    BindDetail("")
  EndIf
EndProcedure

; Switches the detail pane to another profile, saving the current one first.
Procedure SwitchProfile(name$)
  Define.i index, count, found = -1
  If name$ = CurrentName$
    ProcedureReturn
  EndIf
  If CurrentName$ <> "" And Not SaveCurrent(#True)
    count = CountGadgetItems(#G_ProfileList)
    For index = 0 To count - 1
      If GetGadgetItemText(#G_ProfileList, index) = CurrentName$
        SetGadgetState(#G_ProfileList, index)
      EndIf
    Next
    ProcedureReturn
  EndIf
  BindDetail(name$)
EndProcedure

; Reads the checkbox state back into the model after a click on the file list.
Procedure SyncFileChecks()
  Define.i index, row, changed = #False
  If CurrentName$ = ""
    ProcedureReturn
  EndIf
  Define *p.Profile : *p = FindProfilePtr(CurrentName$)
  If *p = 0
    ProcedureReturn
  EndIf
  For index = 0 To ProfileFileCount(*p\ID) - 1
    Define *file.ProfileFile : *file = ProfileFilePtr(*p\ID, index)
    row = Bool(GetGadgetItemState(#G_Files, index) & #PB_ListIcon_Checked)
    If *file\Enabled <> row
      *file\Enabled = row
      changed = #True
    EndIf
  Next
  If changed
    UpdateDerived()
    DirtyAt = ElapsedMilliseconds()
    DirtyDelay = 500
    SetStatus("Editing...")
  EndIf
EndProcedure

Procedure.b FindFileByPath(id.i, path$)
  ForEach ProfileFiles()
    If ProfileFiles()\ProfileID = id And ProfileFiles()\Path$ = path$
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure AddFilesToProfile(paths$)
  Define.i index, count, id
  Define.s path$
  If CurrentName$ = ""
    ProcedureReturn
  EndIf
  Define *p.Profile : *p = FindProfilePtr(CurrentName$)
  If *p = 0
    ProcedureReturn
  EndIf
  count = CountString(paths$, Chr(10)) + 1
  For index = 1 To count
    path$ = AbsPath(StringField(paths$, index, Chr(10)))
    If path$ <> "" And Not FindFileByPath(*p\ID, path$)
      AddProfileFile(*p\ID, path$, #True)
    EndIf
  Next
  RefreshFiles()
  MarkChanged()
EndProcedure

Procedure.i SelectedFilePtr()
  Define.i row = GetGadgetState(#G_Files)
  Define.i index, count
  If row < 0 Or CurrentName$ = ""
    ProcedureReturn 0
  EndIf
  Define *p.Profile : *p = FindProfilePtr(CurrentName$)
  If *p = 0 Or row >= ProfileFileCount(*p\ID)
    ProcedureReturn 0
  EndIf
  ProcedureReturn ProfileFilePtr(*p\ID, row)
EndProcedure

Procedure SwapFileContent(*a.ProfileFile, *b.ProfileFile)
  Define.s path$ = *a\Path$
  Define.i enabled = *a\Enabled
  *a\Path$ = *b\Path$
  *a\Enabled = *b\Enabled
  *b\Path$ = path$
  *b\Enabled = enabled
EndProcedure

Procedure AddFileRequest()
  Define.s file$, selected$
  Define.i count
  file$ = OpenFileRequester("Add files", DoomWadDir(), #WILD_MODS, 0, #PB_Requester_MultiSelection)
  While file$ <> ""
    selected$ + file$ + Chr(10)
    file$ = NextSelectedFileName()
  Wend
  If selected$ <> ""
    AddFilesToProfile(Left(selected$, Len(selected$) - 1))
  EndIf
EndProcedure

Procedure AddFolderRequest()
  Define.s folder$ = PathRequester("Add a folder", DoomWadDir())
  If folder$ <> ""
    AddFilesToProfile(folder$)
  EndIf
EndProcedure

Procedure ToggleSelectedFile()
  Define.i row = GetGadgetState(#G_Files)
  Define.i count
  Define *file.ProfileFile = SelectedFilePtr()
  If *file = 0
    ProcedureReturn
  EndIf
  *file\Enabled = Bool(*file\Enabled = 0)
  RefreshFiles()
  SetGadgetState(#G_Files, row)
  MarkChanged()
EndProcedure

Procedure RemoveSelectedFile()
  Define.i row = GetGadgetState(#G_Files)
  Define.i index, seen, id
  If CurrentName$ = ""
    ProcedureReturn
  EndIf
  Define *p.Profile : *p = FindProfilePtr(CurrentName$)
  If *p = 0 Or row < 0 Or row >= ProfileFileCount(*p\ID)
    ProcedureReturn
  EndIf
  seen = 0
  ForEach ProfileFiles()
    If ProfileFiles()\ProfileID = *p\ID
      If seen = row
        DeleteElement(ProfileFiles())
        Break
      EndIf
      seen + 1
    EndIf
  Next
  RefreshFiles()
  If row >= ProfileFileCount(*p\ID)
    row = ProfileFileCount(*p\ID) - 1
  EndIf
  If row >= 0
    SetGadgetState(#G_Files, row)
  EndIf
  MarkChanged()
EndProcedure

Procedure MoveSelectedFile(delta.i)
  Define.i row = GetGadgetState(#G_Files)
  Define.i target = row + delta
  Define *a.ProfileFile, *b.ProfileFile
  If CurrentName$ = ""
    ProcedureReturn
  EndIf
  Define *p.Profile : *p = FindProfilePtr(CurrentName$)
  If *p = 0 Or row < 0 Or target < 0 Or target >= ProfileFileCount(*p\ID)
    ProcedureReturn
  EndIf
  *a = ProfileFilePtr(*p\ID, row)
  *b = ProfileFilePtr(*p\ID, target)
  SwapFileContent(*a, *b)
  RefreshFiles()
  SetGadgetState(#G_Files, target)
  MarkChanged()
EndProcedure

Procedure BrowseInto(gadget.i, title$, folder.b)
  Define.s current$ = Trim(GetGadgetText(gadget))
  Define.s chosen$
  If folder
    chosen$ = PathRequester(title$, current$)
  Else
    chosen$ = OpenFileRequester(title$, current$, #WILD_CONFIG, 0)
  EndIf
  If chosen$ <> ""
    SetGadgetText(gadget, chosen$)
    MarkChanged()
  EndIf
EndProcedure

Procedure SetCoverRequest()
  Define.s source$, destination$, extension$
  Define.i newImage
  If CurrentName$ = ""
    ProcedureReturn
  EndIf
  Define *p.Profile : *p = FindProfilePtr(CurrentName$)
  If *p = 0
    ProcedureReturn
  EndIf
  source$ = OpenFileRequester("Choose cover art", "", #WILD_IMAGES, 0)
  If source$ = ""
    ProcedureReturn
  EndIf
  EnsureDir(ProfileDirPath(*p))
  extension$ = LCase(ExtLower(source$))
  If extension$ = ""
    extension$ = ".png"
  EndIf
  destination$ = PathJoin(ProfileDirPath(*p), "cover" + extension$)
  If LCase(AbsPath(source$)) <> LCase(AbsPath(destination$))
    If Not CopyFile(source$, destination$)
      ShowError("Could not copy " + source$)
      ProcedureReturn
    EndIf
  EndIf
  *p\Image$ = destination$
  LoadCoverInto(*p)
  MarkChanged()
EndProcedure

Procedure LaunchCurrent()
  Define.i handle
  If Not SaveCurrent(#True)
    ProcedureReturn
  EndIf
  If CurrentName$ = ""
    InfoMessage("Select a profile first.")
    ProcedureReturn
  EndIf
  Define *p.Profile : *p = FindProfilePtr(CurrentName$)
  If *p = 0
    ProcedureReturn
  EndIf
  If Not BuildLaunch(*p)
    ShowError(LastError$)
    ProcedureReturn
  EndIf
  handle = LaunchProfile(*p)
  If handle = 0
    ShowError(LastError$)
    ProcedureReturn
  EndIf
  InfoMessage("Launched " + *p\Name$)
  SetStatus("Running: " + *p\Name$)
EndProcedure

Procedure DuplicateCurrent()
  Define.s base$, name$
  Define.i counter = 2, id, index
  If Not SaveCurrent(#True)
    ProcedureReturn
  EndIf
  Define *source.Profile : *source = FindProfilePtr(CurrentName$)
  If *source = 0
    ProcedureReturn
  EndIf
  base$ = *source\Name$ + " copy"
  name$ = base$
  While FindProfilePtr(name$)
    name$ = base$ + " " + Str(counter)
    counter + 1
  Wend
  id = AddProfileEntry(name$, *source\PortName$, *source\IwadName$, *source\Args$)
  If id = 0
    ShowError(LastError$)
    ProcedureReturn
  EndIf
  Define *clone.Profile : *clone = FindProfileByID(id)
  *clone\Image$ = *source\Image$
  *clone\WorkDir$ = *source\WorkDir$
  *clone\IsolateConfig = *source\IsolateConfig
  *clone\IsolateSaves = *source\IsolateSaves
  For index = 0 To ProfileFileCount(*source\ID) - 1
    Define *file.ProfileFile : *file = ProfileFilePtr(*source\ID, index)
    AddProfileFile(id, *file\Path$, *file\Enabled)
  Next
  WriteConfig()
  RefreshProfileList(name$)
EndProcedure

Procedure DeleteCurrent()
  Define.i answer
  If CurrentName$ = ""
    ProcedureReturn
  EndIf
  answer = MessageRequester("Delete profile", "Delete the profile '" + CurrentName$ + "'?", #PB_MessageRequester_YesNo | #PB_MessageRequester_Warning)
  If answer = #PB_MessageRequester_Yes
    RemoveProfileEntry(CurrentName$)
    CurrentName$ = ""
    WriteConfig()
    RefreshProfileList()
  EndIf
EndProcedure

Procedure ValidateAll()
  Define.s errors$ = ""
  ForEach Profiles()
    Define *p.Profile = @Profiles()
    If Not BuildLaunch(*p)
      errors$ + Profiles()\Name$ + ": " + LastError$ + Chr(10)
    EndIf
  Next
  If errors$ <> ""
    MessageRequester("Profile validation", Trim(errors$), #PB_MessageRequester_Warning)
  Else
    InfoMessage("All profiles look valid.")
  EndIf
EndProcedure

Procedure SaveUiState()
  If IsWindow(#Win_Main)
    UiHasGeometry = #True
    UiX = WindowX(#Win_Main)
    UiY = WindowY(#Win_Main)
    UiW = WindowWidth(#Win_Main)
    UiH = WindowHeight(#Win_Main)
  EndIf
  UiSelected$ = CurrentName$
EndProcedure

Procedure ReloadConfig(path$)
  Define.i saved
  If Not SaveCurrent(#False)
    ProcedureReturn
  EndIf
  If Not LoadConfig(path$)
    ShowError(LastError$)
    ProcedureReturn
  EndIf
  CurrentName$ = ""
  SetStatus("Loaded " + ConfigPath$)
  RefreshProfileList(UiSelected$)
EndProcedure

Procedure.s FindProfileNameByID(id.i)
  Define *p.Profile = FindProfileByID(id)
  If *p
    ProcedureReturn *p\Name$
  EndIf
  ProcedureReturn ""
EndProcedure

Procedure ImportFromRequest()
  Define.s path$ = OpenFileRequester("Import a profile", "", #WILD_PROFILES, 0)
  Define.i id
  If path$ = ""
    ProcedureReturn
  EndIf
  id = ImportProfileFile(path$)
  If id = 0
    ShowError(LastError$)
    ProcedureReturn
  EndIf
  WriteConfig()
  RefreshProfileList(FindProfileNameByID(id))
EndProcedure

Procedure OpenZdlFromRequest()
  Define.s path$ = OpenFileRequester("Open a ZDL file", "", #WILD_ZDL, 0)
  If path$ = ""
    ProcedureReturn
  EndIf
  If Not LoadZdlProfileText(ReadTextFile(path$), StemName(path$))
    ClearZdlProfile()
    ShowError(LastError$)
    ProcedureReturn
  EndIf
  If LaunchProfile(@ZdlProfile)
    SetStatus("Running: " + StemName(path$))
  Else
    ShowError(LastError$)
  EndIf
  ClearZdlProfile()
EndProcedure

Procedure NewProfileRequest()
  Define.s name$
  If ListSize(Ports()) = 0 Or ListSize(Iwads()) = 0
    InfoMessage("Add a source port and an IWAD in Preferences first.")
    ProcedureReturn
  EndIf
  If Not SaveCurrent(#True)
    ProcedureReturn
  EndIf
  If Not OpenNewProfileDialog()
    ProcedureReturn
  EndIf
  name$ = ResultName$
  If AddProfileEntry(name$, DialogPort$, DialogIwad$) = 0
    ShowError(LastError$)
    ProcedureReturn
  EndIf
  WriteConfig()
  RefreshProfileList(name$)
EndProcedure

Procedure OpenPreferencesRequest()
  If Not SaveCurrent(#True)
    ProcedureReturn
  EndIf
  If OpenPreferencesDialog()
    WriteConfig()
    RefreshProfileList(CurrentName$)
    SetStatus("Preferences saved")
  EndIf
EndProcedure

Procedure HandleMenu(menu.i)
  Select menu
    Case #Menu_New : NewProfileRequest()
    Case #Menu_Open : OpenZdlFromRequest()
    Case #Menu_Import : ImportFromRequest()
    Case #Menu_Save : SaveCurrent(#True)
    Case #Menu_Reload : ReloadConfig(ConfigPath$)
    Case #Menu_OpenConfig
      Define.s chosen$ = OpenFileRequester("Choose a config file", ConfigPath$, #WILD_CONFIGS, 0)
      If chosen$ <> ""
        ReloadConfig(chosen$)
      EndIf
    Case #Menu_OpenConfigDir : OpenFolderInExplorer(PyzdlRoot$)
    Case #Menu_OpenWadDir : OpenFolderInExplorer(DoomWadDir())
    Case #Menu_Quit : PostEvent(#PB_Event_CloseWindow, #Win_Main, 0)
    Case #Menu_Launch : LaunchCurrent()
    Case #Menu_Duplicate : DuplicateCurrent()
    Case #Menu_Delete : DeleteCurrent()
    Case #Menu_OpenProfileDir
      If CurrentName$ <> ""
        Define *p.Profile : *p = FindProfilePtr(CurrentName$)
        If *p
          OpenFolderInExplorer(ProfileDirPath(*p))
        EndIf
      EndIf
    Case #Menu_Prefs : OpenPreferencesRequest()
    Case #Menu_Validate : ValidateAll()
    Case #Menu_About
      MessageRequester("About pyZDL", "pyZDL" + Chr(10) + "A GZDoom profile launcher.", #PB_MessageRequester_Info)
  EndSelect
EndProcedure

Procedure BuildMenus()
  CreateMenu(0, WindowID(#Win_Main))
  MenuTitle("&File")
  MenuItem(#Menu_New, "New profile" + Chr(9) + "Ctrl+N")
  MenuItem(#Menu_Open, "Open ZDL..." + Chr(9) + "Ctrl+O")
  MenuItem(#Menu_Import, "Import profile...")
  MenuBar()
  MenuItem(#Menu_Save, "Save" + Chr(9) + "Ctrl+S")
  MenuItem(#Menu_Reload, "Reload from disk" + Chr(9) + "F5")
  MenuItem(#Menu_OpenConfig, "Open config...")
  MenuBar()
  MenuItem(#Menu_OpenConfigDir, "Open config folder")
  MenuItem(#Menu_OpenWadDir, "Open WAD folder")
  MenuBar()
  MenuItem(#Menu_Quit, "Quit" + Chr(9) + "Ctrl+Q")

  MenuTitle("&Profile")
  MenuItem(#Menu_Launch, "Launch" + Chr(9) + "Ctrl+L")
  MenuItem(#Menu_Duplicate, "Duplicate")
  MenuItem(#Menu_Delete, "Delete")
  MenuBar()
  MenuItem(#Menu_OpenProfileDir, "Open profile folder")

  MenuTitle("&Tools")
  MenuItem(#Menu_Prefs, "Preferences..." + Chr(9) + "Ctrl+,")
  MenuItem(#Menu_Validate, "Validate profiles")

  MenuTitle("&Help")
  MenuItem(#Menu_About, "About pyZDL")

  AddKeyboardShortcut(#Win_Main, #PB_Shortcut_Control | #PB_Shortcut_N, #Menu_New)
  AddKeyboardShortcut(#Win_Main, #PB_Shortcut_Control | #PB_Shortcut_O, #Menu_Open)
  AddKeyboardShortcut(#Win_Main, #PB_Shortcut_Control | #PB_Shortcut_S, #Menu_Save)
  AddKeyboardShortcut(#Win_Main, #PB_Shortcut_Control | #PB_Shortcut_L, #Menu_Launch)
  AddKeyboardShortcut(#Win_Main, #PB_Shortcut_Control | #PB_Shortcut_Q, #Menu_Quit)
  AddKeyboardShortcut(#Win_Main, #PB_Shortcut_F5, #Menu_Reload)
EndProcedure

Procedure BuildMainGadgets()
  ; Labels and controls are created at a placeholder position; LayoutMain places them.
  TextGadget(#G_Info, 0, 0, 10, 10, "", #PB_Text_Border)
  TextGadget(#G_SearchLabel, 0, 0, 10, 10, "Search")
  StringGadget(#G_Search, 0, 0, 10, 10, "")
  TextGadget(#G_ProfilesTitle, 0, 0, 10, 10, "Profiles")
  SetGadgetFont(#G_ProfilesTitle, FontID(FontBold))
  TextGadget(#G_Count, 0, 0, 10, 10, "0", #PB_Text_Right)
  ListViewGadget(#G_ProfileList, 0, 0, 10, 10)
  ButtonGadget(#G_BtnNew, 0, 0, 10, 10, "New")
  ButtonGadget(#G_BtnDup, 0, 0, 10, 10, "Duplicate")
  ButtonGadget(#G_BtnDel, 0, 0, 10, 10, "Delete")

  ScrollAreaGadget(#G_Detail, 0, 0, 10, 10, 600, 900, 12)
  ImageGadget(#G_Cover, 16, 16, 150, 190, 0, #PB_Image_Border)
  StringGadget(#G_Name, 0, 0, 10, 10, "")
  SetGadgetFont(#G_Name, FontID(FontTitle))
  TextGadget(#G_Meta, 0, 0, 10, 10, "")
  TextGadget(#G_PortLabel, 0, 0, 10, 10, "Port")
  ComboBoxGadget(#G_Port, 0, 0, 10, 10)
  TextGadget(#G_IwadLabel, 0, 0, 10, 10, "IWAD")
  ComboBoxGadget(#G_Iwad, 0, 0, 10, 10)
  ButtonGadget(#G_BtnLaunch, 0, 0, 10, 10, "Launch")
  SetGadgetFont(#G_BtnLaunch, FontID(FontBold))
  ButtonGadget(#G_BtnSave, 0, 0, 10, 10, "Save")
  ButtonGadget(#G_BtnCover, 0, 0, 10, 10, "Set cover...")
  ButtonGadget(#G_BtnOpenFolder, 0, 0, 10, 10, "Open folder")
  TextGadget(#G_LoadTitle, 0, 0, 10, 10, "Load order")
  SetGadgetFont(#G_LoadTitle, FontID(FontBold))
  TextGadget(#G_LoadHint, 0, 0, 10, 10, "Files are passed to the source port in this order. Drag files here to add them.")
  ListIconGadget(#G_Files, 0, 0, 10, 10, "On", 44, #PB_ListIcon_CheckBoxes | #PB_ListIcon_FullRowSelect)
  AddGadgetColumn(#G_Files, 1, "Mod", 200)
  AddGadgetColumn(#G_Files, 2, "Path", 300)
  EnableGadgetDrop(#G_Files, #PB_Drop_Files, #PB_Drag_Copy)
  ButtonGadget(#G_BtnAddFiles, 0, 0, 10, 10, "Add files...")
  ButtonGadget(#G_BtnAddFolder, 0, 0, 10, 10, "Add folder...")
  ButtonGadget(#G_BtnToggle, 0, 0, 10, 10, "Enable / disable")
  ButtonGadget(#G_BtnRemove, 0, 0, 10, 10, "Remove")
  ButtonGadget(#G_BtnUp, 0, 0, 10, 10, "Up")
  ButtonGadget(#G_BtnDown, 0, 0, 10, 10, "Down")
  ButtonGadget(#G_BtnOpenFile, 0, 0, 10, 10, "Open")
  FrameGadget(#G_IsoFrame, 0, 0, 10, 10, "Config and saves")
  TextGadget(#G_CfgLabel, 0, 0, 10, 10, "Config")
  ComboBoxGadget(#G_CfgMode, 0, 0, 10, 10)
  AddGadgetItem(#G_CfgMode, -1, "Use global default")
  AddGadgetItem(#G_CfgMode, -1, "Isolated")
  AddGadgetItem(#G_CfgMode, -1, "Shared")
  StringGadget(#G_CfgPath, 0, 0, 10, 10, "")
  ButtonGadget(#G_CfgBrowse, 0, 0, 10, 10, "Browse...")
  ButtonGadget(#G_CfgOpen, 0, 0, 10, 10, "Open")
  TextGadget(#G_CfgHint, 0, 0, 10, 10, "")
  TextGadget(#G_SavesLabel, 0, 0, 10, 10, "Saves")
  ComboBoxGadget(#G_SavesMode, 0, 0, 10, 10)
  AddGadgetItem(#G_SavesMode, -1, "Use global default")
  AddGadgetItem(#G_SavesMode, -1, "Isolated")
  AddGadgetItem(#G_SavesMode, -1, "Shared")
  StringGadget(#G_SavesPath, 0, 0, 10, 10, "")
  ButtonGadget(#G_SavesBrowse, 0, 0, 10, 10, "Browse...")
  ButtonGadget(#G_SavesOpen, 0, 0, 10, 10, "Open")
  TextGadget(#G_SavesHint, 0, 0, 10, 10, "")
  TextGadget(#G_WorkLabel, 0, 0, 10, 10, "Working dir")
  StringGadget(#G_WorkPath, 0, 0, 10, 10, "")
  ButtonGadget(#G_WorkBrowse, 0, 0, 10, 10, "Browse...")
  TextGadget(#G_ArgsTitle, 0, 0, 10, 10, "Extra arguments")
  SetGadgetFont(#G_ArgsTitle, FontID(FontBold))
  EditorGadget(#G_Args, 0, 0, 10, 10, #PB_Editor_WordWrap)
  TextGadget(#G_PreviewTitle, 0, 0, 10, 10, "Command preview")
  SetGadgetFont(#G_PreviewTitle, FontID(FontBold))
  EditorGadget(#G_Preview, 0, 0, 10, 10, #PB_Editor_ReadOnly | #PB_Editor_WordWrap)
  CloseGadgetList()
EndProcedure

; Positions every main-window gadget for a client area of w x h.
Procedure LayoutMain(w.i, h.i)
  Define.i leftW = 290, top = 30, y, detailW, innerW, cw, aw, x, rightX, fileW, isoY, isoH, rowY
  Define.i portLabelW = 40, gap = 8, labelW = 70
  If w < 600 Or h < 300
    ProcedureReturn
  EndIf
  ResizeGadget(#G_Info, 0, 0, w, 24)
  ResizeGadget(#G_SearchLabel, 10, 34, 60, 20)
  ResizeGadget(#G_Search, 10, 56, leftW - 20, 24)
  ResizeGadget(#G_ProfilesTitle, 10, 90, 120, 20)
  ResizeGadget(#G_Count, leftW - 70, 90, 60, 20)
  ResizeGadget(#G_ProfileList, 10, 116, leftW - 20, h - 116 - 52)
  ResizeGadget(#G_BtnNew, 10, h - 40, 80, 28)
  ResizeGadget(#G_BtnDup, 96, h - 40, 92, 28)
  ResizeGadget(#G_BtnDel, leftW - 90, h - 40, 80, 28)

  detailW = w - leftW
  ResizeGadget(#G_Detail, leftW, top, detailW, h - top)
  innerW = detailW - 20
  aw = innerW - 182 - 16
  If aw < 300
    aw = 300
  EndIf

  ResizeGadget(#G_Name, 182, 16, aw, 28)
  ResizeGadget(#G_Meta, 182, 52, aw, 18)
  ResizeGadget(#G_PortLabel, 182, 80, portLabelW, 20)
  cw = (aw - portLabelW - 6 - 14 - portLabelW - 6) / 2
  ResizeGadget(#G_Port, 182 + portLabelW + 6, 76, cw, 24)
  ResizeGadget(#G_IwadLabel, 182 + portLabelW + 6 + cw + 14, 80, portLabelW, 20)
  ResizeGadget(#G_Iwad, 182 + portLabelW + 6 + cw + 14 + portLabelW + 6, 76, cw, 24)

  x = 182
  ResizeGadget(#G_BtnLaunch, x, 112, 120, 30)
  ResizeGadget(#G_BtnSave, x + 128, 112, 90, 30)
  ResizeGadget(#G_BtnCover, x + 226, 112, 110, 30)
  ResizeGadget(#G_BtnOpenFolder, x + 344, 112, 120, 30)

  y = 230
  ResizeGadget(#G_LoadTitle, 16, y, 200, 20)
  ResizeGadget(#G_LoadHint, 16, y + 22, innerW - 32, 20)
  fileW = innerW - 32
  ResizeGadget(#G_Files, 16, y + 48, fileW, 170)
  rowY = y + 48 + 170 + 8
  ResizeGadget(#G_BtnAddFiles, 16, rowY, 96, 28)
  ResizeGadget(#G_BtnAddFolder, 118, rowY, 104, 28)
  ResizeGadget(#G_BtnToggle, 228, rowY, 120, 28)
  ResizeGadget(#G_BtnRemove, 354, rowY, 84, 28)
  ResizeGadget(#G_BtnUp, 446, rowY, 40, 28)
  ResizeGadget(#G_BtnDown, 492, rowY, 40, 28)
  ResizeGadget(#G_BtnOpenFile, 16 + fileW - 70, rowY, 70, 28)

  isoY = rowY + 44
  isoH = 292
  ResizeGadget(#G_IsoFrame, 16, isoY, innerW - 32, isoH)
  rightX = 16 + 12
  rowY = isoY + 26
  ResizeGadget(#G_CfgLabel, rightX, rowY + 4, labelW, 20)
  ResizeGadget(#G_CfgMode, rightX + labelW, rowY, 150, 24)
  ResizeGadget(#G_CfgPath, rightX + labelW + 158, rowY, innerW - 32 - 24 - labelW - 158 - 170, 24)
  ResizeGadget(#G_CfgBrowse, innerW - 32 - 12 - 160 - 4, rowY, 80, 24)
  ResizeGadget(#G_CfgOpen, innerW - 32 - 12 - 76, rowY, 70, 24)
  ResizeGadget(#G_CfgHint, rightX + labelW, rowY + 30, innerW - 32 - 24 - labelW, 34)

  rowY = isoY + 94
  ResizeGadget(#G_SavesLabel, rightX, rowY + 4, labelW, 20)
  ResizeGadget(#G_SavesMode, rightX + labelW, rowY, 150, 24)
  ResizeGadget(#G_SavesPath, rightX + labelW + 158, rowY, innerW - 32 - 24 - labelW - 158 - 170, 24)
  ResizeGadget(#G_SavesBrowse, innerW - 32 - 12 - 160 - 4, rowY, 80, 24)
  ResizeGadget(#G_SavesOpen, innerW - 32 - 12 - 76, rowY, 70, 24)
  ResizeGadget(#G_SavesHint, rightX + labelW, rowY + 30, innerW - 32 - 24 - labelW, 34)

  rowY = isoY + 206
  ResizeGadget(#G_WorkLabel, rightX, rowY + 4, labelW + 10, 20)
  ResizeGadget(#G_WorkPath, rightX + labelW + 10, rowY, innerW - 32 - 24 - labelW - 10 - 92, 24)
  ResizeGadget(#G_WorkBrowse, innerW - 32 - 12 - 80, rowY, 80, 24)

  y = isoY + isoH + 16
  ResizeGadget(#G_ArgsTitle, 16, y, 200, 20)
  ResizeGadget(#G_Args, 16, y + 22, innerW - 32, 60)
  y = y + 22 + 60 + 14
  ResizeGadget(#G_PreviewTitle, 16, y, 200, 20)
  ResizeGadget(#G_Preview, 16, y + 22, innerW - 32, 80)
  y = y + 22 + 80 + 16

  SetGadgetAttribute(#G_Detail, #PB_ScrollArea_InnerWidth, innerW)
  If y < h - top
    y = h - top
  EndIf
  SetGadgetAttribute(#G_Detail, #PB_ScrollArea_InnerHeight, y)
EndProcedure

Procedure OpenMainWindow()
  Define.i x = #PB_Ignore, y = #PB_Ignore, width = 1100, height = 820, flags
  flags = #PB_Window_SystemMenu | #PB_Window_SizeGadget | #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget
  If UiHasGeometry And UiW >= 900 And UiH >= 640
    x = UiX
    y = UiY
    width = UiW
    height = UiH
  Else
    flags = flags | #PB_Window_ScreenCentered
  EndIf
  If Not OpenWindow(#Win_Main, x, y, width, height, "pyZDL", flags)
    ProcedureReturn #False
  EndIf
  WindowBounds(#Win_Main, 900, 640, #PB_Ignore, #PB_Ignore)
  BuildMenus()
  CreateStatusBar(0, WindowID(#Win_Main))
  AddStatusBarField(560)
  AddStatusBarField(#PB_Ignore)
  BuildMainGadgets()
  LayoutMain(WindowWidth(#Win_Main, #PB_Window_InnerCoordinate), WindowHeight(#Win_Main, #PB_Window_InnerCoordinate) - StatusBarHeight(0))
  ProcedureReturn #True
EndProcedure

Procedure HandleProfileEvent(eventType.i)
  Define.i index
  index = GetGadgetState(#G_ProfileList)
  If index < 0
    ProcedureReturn
  EndIf
  If eventType = #PB_EventType_LeftDoubleClick
    SwitchProfile(GetGadgetItemText(#G_ProfileList, index))
    LaunchCurrent()
    ProcedureReturn
  EndIf
  SwitchProfile(GetGadgetItemText(#G_ProfileList, index))
EndProcedure

Procedure HandleGadget(gadget.i, eventType.i)
  Define *p.Profile
  Select gadget
    Case #G_ProfileList
      HandleProfileEvent(eventType)
    Case #G_Search
      If eventType = #PB_EventType_Change
        RefreshProfileList(CurrentName$)
      EndIf
    Case #G_BtnNew : NewProfileRequest()
    Case #G_BtnDup : DuplicateCurrent()
    Case #G_BtnDel : DeleteCurrent()
    Case #G_Name
      If eventType = #PB_EventType_Change
        MarkChanged(#True)
      ElseIf eventType = #PB_EventType_LostFocus
        SaveCurrent(#True)
      EndIf
    Case #G_Port, #G_Iwad, #G_CfgMode, #G_SavesMode
      If eventType = #PB_EventType_Change
        MarkChanged()
      EndIf
    Case #G_CfgPath, #G_SavesPath, #G_WorkPath, #G_Args
      If eventType = #PB_EventType_Change
        MarkChanged()
      EndIf
    Case #G_Files
      If eventType = #PB_EventType_LeftClick Or eventType = #PB_EventType_LeftDoubleClick
        CheckSyncAt = ElapsedMilliseconds() + 60
      EndIf
    Case #G_BtnLaunch : LaunchCurrent()
    Case #G_BtnSave : If SaveCurrent(#True) : InfoMessage("Saved.") : EndIf
    Case #G_BtnCover : SetCoverRequest()
    Case #G_BtnOpenFolder
      If CurrentName$ <> ""
        *p = FindProfilePtr(CurrentName$)
        If *p
          OpenFolderInExplorer(ProfileDirPath(*p))
        EndIf
      EndIf
    Case #G_BtnAddFiles : AddFileRequest()
    Case #G_BtnAddFolder : AddFolderRequest()
    Case #G_BtnToggle : ToggleSelectedFile()
    Case #G_BtnRemove : RemoveSelectedFile()
    Case #G_BtnUp : MoveSelectedFile(-1)
    Case #G_BtnDown : MoveSelectedFile(1)
    Case #G_BtnOpenFile
      Define *file.ProfileFile = SelectedFilePtr()
      If *file
        OpenPathInShell(*file\Path$)
      EndIf
    Case #G_CfgBrowse : BrowseInto(#G_CfgPath, "Choose a GZDoom config", #False)
    Case #G_SavesBrowse : BrowseInto(#G_SavesPath, "Choose a save folder", #True)
    Case #G_WorkBrowse : BrowseInto(#G_WorkPath, "Choose a working directory", #True)
    Case #G_CfgOpen
      Define.s cfgFile$ = Trim(GetGadgetText(#G_CfgPath))
      If cfgFile$ = "" And CurrentName$ <> ""
        *p = FindProfilePtr(CurrentName$)
        If *p
          cfgFile$ = ProfileDefaultConfig(*p)
        EndIf
      EndIf
      If cfgFile$ <> ""
        If IsDirPath(cfgFile$)
          OpenFolderInExplorer(cfgFile$)
        Else
          OpenFolderInExplorer(DirName(cfgFile$))
        EndIf
      EndIf
    Case #G_SavesOpen
      Define.s savesPath$ = Trim(GetGadgetText(#G_SavesPath))
      If savesPath$ = "" And CurrentName$ <> ""
        *p = FindProfilePtr(CurrentName$)
        If *p
          savesPath$ = ProfileSavePath(*p)
        EndIf
      EndIf
      If savesPath$ <> ""
        OpenFolderInExplorer(savesPath$)
      EndIf
  EndSelect
EndProcedure

Procedure TickGui()
  If DirtyAt > 0 And ElapsedMilliseconds() - DirtyAt >= DirtyDelay
    If GetActiveGadget() <> #G_Name Or DirtyDelay <> 1200
      SaveCurrent(#False)
    EndIf
  EndIf
  If CheckSyncAt > 0 And ElapsedMilliseconds() >= CheckSyncAt
    CheckSyncAt = 0
    SyncFileChecks()
  EndIf
  If ReapGame()
    SetStatus(FinishedName$ + " exited (" + Str(FinishedCode) + ")")
  EndIf
EndProcedure

Procedure.i RunGui(startPath$)
  Define.i event, quit = #False
  Define.s loadError$
  UsePNGImageDecoder()
  UseJPEGImageDecoder()
  If Not LoadConfig(startPath$)
    MessageRequester("pyZDL", LastError$, #PB_MessageRequester_Error)
    ProcedureReturn 1
  EndIf
  FontTitle = LoadFont(#PB_Any, #PYZ_FONT$, 13, #PB_Font_Bold)
  FontBold = LoadFont(#PB_Any, #PYZ_FONT$, 9, #PB_Font_Bold)
  If Not OpenMainWindow()
    ProcedureReturn 1
  EndIf
  DirtyAt = 0
  DirtyDelay = 500
  CheckSyncAt = 0
  Loading = #False
  RefreshProfileList(UiSelected$)
  SetStatus("Ready")
  Repeat
    event = WaitWindowEvent(100)
    Select event
      Case #PB_Event_CloseWindow
        quit = #True
      Case #PB_Event_Menu
        HandleMenu(EventMenu())
      Case #PB_Event_SizeWindow
        LayoutMain(WindowWidth(#Win_Main, #PB_Window_InnerCoordinate), WindowHeight(#Win_Main, #PB_Window_InnerCoordinate) - StatusBarHeight(0))
      Case #PB_Event_Gadget
        HandleGadget(EventGadget(), EventType())
      Case #PB_Event_GadgetDrop
        If EventGadget() = #G_Files
          AddFilesToProfile(EventDropFiles())
        ElseIf EventGadget() = #G_ProfileList
          ; Dropping on the profile list is ignored.
        EndIf
    EndSelect
    TickGui()
  Until quit
  SaveCurrent(#False)
  SaveUiState()
  WriteConfig()
  CloseWindow(#Win_Main)
  ProcedureReturn 0
EndProcedure
