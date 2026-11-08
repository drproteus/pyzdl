; Modal dialogs: new profile, add or edit a source port or IWAD, and preferences.
; Mirrors wxui/dialogs.py. Included before gui.pbi.

#WILD_DOOM_FILES = "Doom files (*.wad;*.iwad;*.pk3;*.ipk3;*.zip;*.deh;*.bex)|*.wad;*.iwad;*.pk3;*.ipk3;*.zip;*.deh;*.bex|All files (*.*)|*.*"

Procedure.s StagedLabel(name$, path$)
  ProcedureReturn name$ + "  -  " + path$
EndProcedure

Procedure.b OpenNewProfileDialog()
  Define.i event, ok = #False, closed = #False, index
  Define.s name$
  If Not OpenWindow(#Win_NewProfile, 0, 0, 420, 190, "New Profile", #PB_Window_ScreenCentered | #PB_Window_SystemMenu)
    ProcedureReturn #False
  EndIf
  TextGadget(#PB_Any, 16, 20, 90, 20, "Name")
  StringGadget(#DG_NewName, 110, 16, 290, 24, "")
  TextGadget(#PB_Any, 16, 56, 90, 20, "Source port")
  ComboBoxGadget(#DG_NewPort, 110, 52, 290, 24)
  TextGadget(#PB_Any, 16, 92, 90, 20, "IWAD")
  ComboBoxGadget(#DG_NewIwad, 110, 88, 290, 24)
  ButtonGadget(#DG_NewCreate, 240, 140, 75, 28, "Create")
  ButtonGadget(#DG_NewCancel, 325, 140, 75, 28, "Cancel")
  ForEach Ports()
    AddGadgetItem(#DG_NewPort, -1, Ports()\Name$)
  Next
  SetGadgetState(#DG_NewPort, 0)
  ForEach Iwads()
    AddGadgetItem(#DG_NewIwad, -1, Iwads()\Name$)
  Next
  SetGadgetState(#DG_NewIwad, 0)
  SetActiveGadget(#DG_NewName)
  DisableWindow(#Win_Main, #True)
  Repeat
    event = WaitWindowEvent()
    If event = #PB_Event_CloseWindow
      closed = #True
    ElseIf event = #PB_Event_Gadget
      If EventGadget() = #DG_NewCancel
        closed = #True
      ElseIf EventGadget() = #DG_NewCreate
        name$ = Trim(GetGadgetText(#DG_NewName))
        If name$ = ""
          MessageRequester("Invalid name", "Please enter a profile name.", #PB_MessageRequester_Warning)
        ElseIf FindProfilePtr(name$)
          MessageRequester("Duplicate name", "A profile named '" + name$ + "' already exists.", #PB_MessageRequester_Warning)
        ElseIf GetGadgetState(#DG_NewPort) < 0 Or GetGadgetState(#DG_NewIwad) < 0
          MessageRequester("Nothing to launch", "Add a source port and an IWAD first.", #PB_MessageRequester_Warning)
        Else
          ResultName$ = name$
          DialogPort$ = GetGadgetText(#DG_NewPort)
          DialogIwad$ = GetGadgetText(#DG_NewIwad)
          ok = #True
          closed = #True
        EndIf
      EndIf
    EndIf
  Until closed
  DisableWindow(#Win_Main, #False)
  CloseWindow(#Win_NewProfile)
  SetActiveWindow(#Win_Main)
  ProcedureReturn ok
EndProcedure

Procedure.b OpenResourceDialog(title$, name$, path$, folderMode.b, wildcard$)
  Define.i event, ok = #False, closed = #False
  Define.s chosen$, pathValue$
  If Not OpenWindow(#Win_Resource, 0, 0, 520, 150, title$, #PB_Window_ScreenCentered | #PB_Window_SystemMenu)
    ProcedureReturn #False
  EndIf
  TextGadget(#PB_Any, 16, 20, 80, 20, "Name")
  StringGadget(#DG_ResName, 100, 16, 400, 24, name$)
  TextGadget(#PB_Any, 16, 56, 80, 20, "Path")
  StringGadget(#DG_ResPath, 100, 52, 300, 24, path$)
  ButtonGadget(#DG_ResBrowse, 408, 52, 92, 24, "Browse...")
  ButtonGadget(#DG_ResOk, 336, 110, 75, 28, "Save")
  ButtonGadget(#DG_ResCancel, 421, 110, 75, 28, "Cancel")
  SetActiveGadget(#DG_ResName)
  DisableWindow(#Win_Main, #True)
  Repeat
    event = WaitWindowEvent()
    If event = #PB_Event_CloseWindow
      closed = #True
    ElseIf event = #PB_Event_Gadget
      If EventGadget() = #DG_ResCancel
        closed = #True
      ElseIf EventGadget() = #DG_ResBrowse
        pathValue$ = Trim(GetGadgetText(#DG_ResPath))
        If folderMode
          chosen$ = PathRequester("Choose a folder", pathValue$)
        Else
          chosen$ = OpenFileRequester("Choose a file", pathValue$, wildcard$, 0)
        EndIf
        If chosen$ <> ""
          SetGadgetText(#DG_ResPath, chosen$)
        EndIf
      ElseIf EventGadget() = #DG_ResOk
        ResultName$ = Trim(GetGadgetText(#DG_ResName))
        ResultPath$ = Trim(GetGadgetText(#DG_ResPath))
        If ResultName$ = ""
          MessageRequester("Invalid name", "Please enter a name.", #PB_MessageRequester_Warning)
        ElseIf ResultPath$ = ""
          MessageRequester("Invalid path", "Please choose a path.", #PB_MessageRequester_Warning)
        ElseIf Not PathExists(ExpandPath(ResultPath$, PyzdlRoot$))
          MessageRequester("Invalid path", "Path does not exist:" + Chr(10) + ResultPath$, #PB_MessageRequester_Warning)
        Else
          ok = #True
          closed = #True
        EndIf
      EndIf
    EndIf
  Until closed
  DisableWindow(#Win_Main, #False)
  CloseWindow(#Win_Resource)
  SetActiveWindow(#Win_Main)
  ProcedureReturn ok
EndProcedure

Procedure.s IIf_Title(adding.b, title$)
  If adding
    ProcedureReturn "Add " + title$
  EndIf
  ProcedureReturn "Edit " + title$
EndProcedure

Procedure.i IIf_Index(adding.b, value.i, index.i)
  If adding
    ProcedureReturn value
  EndIf
  ProcedureReturn index
EndProcedure

Procedure FillResourceList(listGadget.i, isPort.b)
  ClearGadgetItems(listGadget)
  If isPort
    ForEach StagedPorts()
      AddGadgetItem(listGadget, -1, StagedLabel(StagedPorts()\Name$, StagedPorts()\Path$))
    Next
  Else
    ForEach StagedIwads()
      AddGadgetItem(listGadget, -1, StagedLabel(StagedIwads()\Name$, StagedIwads()\Path$))
    Next
  EndIf
EndProcedure

Procedure.b StagedNameTaken(isPort.b, name$, exceptIndex.i)
  Define.i index = 0
  If isPort
    ForEach StagedPorts()
      If index <> exceptIndex And StagedPorts()\Name$ = name$
        ProcedureReturn #True
      EndIf
      index + 1
    Next
  Else
    ForEach StagedIwads()
      If index <> exceptIndex And StagedIwads()\Name$ = name$
        ProcedureReturn #True
      EndIf
      index + 1
    Next
  EndIf
  ProcedureReturn #False
EndProcedure

Procedure.b EditStagedEntry(isPort.b, index.i, adding.b)
  Define.s title$, name$, path$, wildcard$
  Define.i listGadget
  If isPort
    title$ = "Source port"
    wildcard$ = #WILD_APPS
    listGadget = #DG_PortList
  Else
    title$ = "IWAD"
    wildcard$ = #WILD_DOOM_FILES
    listGadget = #DG_IwadList
  EndIf
  If Not adding
    If isPort
      SelectElement(StagedPorts(), index)
      name$ = StagedPorts()\Name$
      path$ = StagedPorts()\Path$
    Else
      SelectElement(StagedIwads(), index)
      name$ = StagedIwads()\Name$
      path$ = StagedIwads()\Path$
    EndIf
  EndIf
  If Not OpenResourceDialog(IIf_Title(adding, title$), name$, path$, #False, wildcard$)
    ProcedureReturn #False
  EndIf
  If StagedNameTaken(isPort, ResultName$, IIf_Index(adding, -1, index))
    MessageRequester("Duplicate name", "Another entry is already named '" + ResultName$ + "'.", #PB_MessageRequester_Warning)
    ProcedureReturn #False
  EndIf
  If isPort
    If adding
      LastElement(StagedPorts()) : AddElement(StagedPorts())
      StagedPorts()\Original$ = ""
    Else
      SelectElement(StagedPorts(), index)
    EndIf
    StagedPorts()\Name$ = ResultName$
    StagedPorts()\Path$ = ResultPath$
  Else
    If adding
      LastElement(StagedIwads()) : AddElement(StagedIwads())
      StagedIwads()\Original$ = ""
    Else
      SelectElement(StagedIwads(), index)
    EndIf
    StagedIwads()\Name$ = ResultName$
    StagedIwads()\Path$ = ResultPath$
  EndIf
  FillResourceList(listGadget, isPort)
  ProcedureReturn #True
EndProcedure

Procedure RemoveStagedEntry(isPort.b, index.i)
  If isPort
    If SelectElement(StagedPorts(), index)
      DeleteElement(StagedPorts())
    EndIf
    FillResourceList(#DG_PortList, #True)
  Else
    If SelectElement(StagedIwads(), index)
      DeleteElement(StagedIwads())
    EndIf
    FillResourceList(#DG_IwadList, #False)
  EndIf
EndProcedure

Procedure.b ValidateStaged(isPort.b)
  If isPort
    ForEach StagedPorts()
      If StagedPorts()\Name$ = ""
        ProcedureReturn Fail("Every resource needs a name.")
      EndIf
      If Not PathExists(ExpandPath(StagedPorts()\Path$, PyzdlRoot$))
        ProcedureReturn Fail("Path does not exist: " + StagedPorts()\Path$)
      EndIf
    Next
  Else
    ForEach StagedIwads()
      If StagedIwads()\Name$ = ""
        ProcedureReturn Fail("Every resource needs a name.")
      EndIf
      If Not PathExists(ExpandPath(StagedIwads()\Path$, PyzdlRoot$))
        ProcedureReturn Fail("Path does not exist: " + StagedIwads()\Path$)
      EndIf
    Next
  EndIf
  ProcedureReturn #True
EndProcedure

Procedure.b StagedKeeps(isPort.b, name$)
  If isPort
    ForEach StagedPorts()
      If StagedPorts()\Original$ = name$
        ProcedureReturn #True
      EndIf
    Next
  Else
    ForEach StagedIwads()
      If StagedIwads()\Original$ = name$
        ProcedureReturn #True
      EndIf
    Next
  EndIf
  ProcedureReturn #False
EndProcedure

; Checks the staged lists before anything is changed. Unlike the Python version
; this runs for both lists before either is applied.
Procedure.b HasDuplicateStagedNames(isPort.b)
  Define.i count, index, a, b
  Dim names.s(0)
  If isPort
    count = ListSize(StagedPorts())
  Else
    count = ListSize(StagedIwads())
  EndIf
  If count < 2
    ProcedureReturn #False
  EndIf
  ReDim names.s(count - 1)
  index = 0
  If isPort
    ForEach StagedPorts()
      names(index) = StagedPorts()\Name$
      index + 1
    Next
  Else
    ForEach StagedIwads()
      names(index) = StagedIwads()\Name$
      index + 1
    Next
  EndIf
  For a = 0 To count - 2
    For b = a + 1 To count - 1
      If names(a) = names(b)
        ProcedureReturn #True
      EndIf
    Next
  Next
  ProcedureReturn #False
EndProcedure

Procedure.b CheckPreferences()
  Define.s users$
  If Not ValidateStaged(#True) Or Not ValidateStaged(#False)
    ProcedureReturn #False
  EndIf
  If HasDuplicateStagedNames(#True) Or HasDuplicateStagedNames(#False)
    ProcedureReturn Fail("Resource names must be unique.")
  EndIf
  ForEach Ports()
    If Not StagedKeeps(#True, Ports()\Name$)
      users$ = UsingPort(Ports()\Name$)
      If users$ <> ""
        ProcedureReturn Fail("Cannot remove source port '" + Ports()\Name$ + "'; it is used by: " + users$)
      EndIf
    EndIf
  Next
  ForEach Iwads()
    If Not StagedKeeps(#False, Iwads()\Name$)
      users$ = UsingIwad(Iwads()\Name$)
      If users$ <> ""
        ProcedureReturn Fail("Cannot remove IWAD '" + Iwads()\Name$ + "'; it is used by: " + users$)
      EndIf
    EndIf
  Next
  ProcedureReturn #True
EndProcedure

; Replaces the port and IWAD lists with the staged copies. Profiles that refer to
; a renamed entry are repointed in the same pass.
Procedure ApplyStagedLists()
  ForEach Profiles()
    ForEach StagedPorts()
      If StagedPorts()\Original$ <> "" And StagedPorts()\Original$ = Profiles()\PortName$
        Profiles()\PortName$ = StagedPorts()\Name$
        Break
      EndIf
    Next
    ForEach StagedIwads()
      If StagedIwads()\Original$ <> "" And StagedIwads()\Original$ = Profiles()\IwadName$
        Profiles()\IwadName$ = StagedIwads()\Name$
        Break
      EndIf
    Next
  Next
  ClearList(Ports())
  ForEach StagedPorts()
    LastElement(Ports()) : AddElement(Ports())
    Ports()\Name$ = StagedPorts()\Name$
    Ports()\Path$ = StagedPorts()\Path$
  Next
  ClearList(Iwads())
  ForEach StagedIwads()
    LastElement(Iwads()) : AddElement(Iwads())
    Iwads()\Name$ = StagedIwads()\Name$
    Iwads()\Path$ = StagedIwads()\Path$
  Next
EndProcedure

Procedure.b OpenPreferencesDialog()
  Define.i event, ok = #False, closed = #False, index, selected
  Define.s wadPath$, normalized$
  If Not OpenWindow(#Win_Prefs, 0, 0, 640, 520, "Preferences", #PB_Window_ScreenCentered | #PB_Window_SystemMenu)
    ProcedureReturn #False
  EndIf
  PanelGadget(#DG_PrefTabs, 12, 12, 616, 448)
  AddGadgetItem(#DG_PrefTabs, -1, "General")
  TextGadget(#PB_Any, 16, 20, 180, 20, "DOOMWADDIR")
  StringGadget(#DG_PrefWadDir, 200, 16, 300, 24, DoomWadDir())
  ButtonGadget(#DG_PrefWadDirBrowse, 508, 16, 80, 24, "Browse...")
  TextGadget(#PB_Any, 16, 56, 180, 20, "DOOMWADPATH")
  StringGadget(#DG_PrefWadPath, 200, 52, 388, 24, DoomWadPathValue())
  TextGadget(#PB_Any, 16, 92, 180, 20, "Default GZDoom config")
  StringGadget(#DG_PrefDefaultConfig, 200, 88, 300, 24, SettingDefaultConfig$)
  ButtonGadget(#DG_PrefDefaultConfigBrowse, 508, 88, 80, 24, "Browse...")
  CheckBoxGadget(#DG_PrefIsoConfig, 16, 136, 560, 22, "Isolate GZDoom config per profile by default")
  SetGadgetState(#DG_PrefIsoConfig, Bool(SettingProfileConfigs))
  CheckBoxGadget(#DG_PrefIsoSaves, 16, 166, 560, 22, "Isolate save games per profile by default")
  SetGadgetState(#DG_PrefIsoSaves, Bool(SettingProfileSaves))
  TextGadget(#PB_Any, 16, 206, 580, 40, "DOOMWADPATH entries are separated with ';'. Profiles can override config and save isolation individually.")

  AddGadgetItem(#DG_PrefTabs, -1, "Source Ports")
  ListViewGadget(#DG_PortList, 16, 16, 580, 340)
  ButtonGadget(#DG_PortAdd, 16, 366, 90, 28, "Add...")
  ButtonGadget(#DG_PortEdit, 112, 366, 90, 28, "Edit...")
  ButtonGadget(#DG_PortRemove, 506, 366, 90, 28, "Remove")

  AddGadgetItem(#DG_PrefTabs, -1, "IWADs")
  ListViewGadget(#DG_IwadList, 16, 16, 580, 340)
  ButtonGadget(#DG_IwadAdd, 16, 366, 90, 28, "Add...")
  ButtonGadget(#DG_IwadEdit, 112, 366, 90, 28, "Edit...")
  ButtonGadget(#DG_IwadRemove, 506, 366, 90, 28, "Remove")
  CloseGadgetList()

  ButtonGadget(#DG_PrefOk, 430, 476, 90, 28, "Save")
  ButtonGadget(#DG_PrefCancel, 526, 476, 90, 28, "Cancel")

  ClearList(StagedPorts())
  ForEach Ports()
    LastElement(StagedPorts()) : AddElement(StagedPorts())
    StagedPorts()\Original$ = Ports()\Name$
    StagedPorts()\Name$ = Ports()\Name$
    StagedPorts()\Path$ = Ports()\Path$
  Next
  ClearList(StagedIwads())
  ForEach Iwads()
    LastElement(StagedIwads()) : AddElement(StagedIwads())
    StagedIwads()\Original$ = Iwads()\Name$
    StagedIwads()\Name$ = Iwads()\Name$
    StagedIwads()\Path$ = Iwads()\Path$
  Next
  FillResourceList(#DG_PortList, #True)
  FillResourceList(#DG_IwadList, #False)

  DisableWindow(#Win_Main, #True)
  Repeat
    event = WaitWindowEvent()
    If event = #PB_Event_CloseWindow
      closed = #True
    ElseIf event = #PB_Event_Gadget
      Select EventGadget()
        Case #DG_PrefCancel
          closed = #True
        Case #DG_PrefWadDirBrowse
          wadPath$ = PathRequester("Choose DOOMWADDIR", Trim(GetGadgetText(#DG_PrefWadDir)))
          If wadPath$ <> ""
            SetGadgetText(#DG_PrefWadDir, wadPath$)
          EndIf
        Case #DG_PrefDefaultConfigBrowse
          wadPath$ = OpenFileRequester("Choose a default GZDoom config", Trim(GetGadgetText(#DG_PrefDefaultConfig)), #WILD_CONFIG, 0)
          If wadPath$ <> ""
            SetGadgetText(#DG_PrefDefaultConfig, wadPath$)
          EndIf
        Case #DG_PortAdd
          EditStagedEntry(#True, 0, #True)
        Case #DG_PortEdit
          selected = GetGadgetState(#DG_PortList)
          If selected >= 0
            EditStagedEntry(#True, selected, #False)
          EndIf
        Case #DG_PortRemove
          selected = GetGadgetState(#DG_PortList)
          If selected >= 0
            RemoveStagedEntry(#True, selected)
          EndIf
        Case #DG_IwadAdd
          EditStagedEntry(#False, 0, #True)
        Case #DG_IwadEdit
          selected = GetGadgetState(#DG_IwadList)
          If selected >= 0
            EditStagedEntry(#False, selected, #False)
          EndIf
        Case #DG_IwadRemove
          selected = GetGadgetState(#DG_IwadList)
          If selected >= 0
            RemoveStagedEntry(#False, selected)
          EndIf
        Case #DG_PrefOk
          If CheckPreferences()
            ApplyStagedLists()
            SettingDoomWadDir$ = Trim(GetGadgetText(#DG_PrefWadDir))
            normalized$ = ReplaceString(GetGadgetText(#DG_PrefWadPath), ",", ";")
            SettingDoomWadPath$ = ""
            For index = 1 To CountString(normalized$, ";") + 1
              wadPath$ = Trim(StringField(normalized$, index, ";"))
              If wadPath$ <> ""
                If SettingDoomWadPath$ <> ""
                  SettingDoomWadPath$ + ";"
                EndIf
                SettingDoomWadPath$ + wadPath$
              EndIf
            Next
            SettingDefaultConfig$ = Trim(GetGadgetText(#DG_PrefDefaultConfig))
            SettingProfileConfigs = GetGadgetState(#DG_PrefIsoConfig)
            SettingProfileSaves = GetGadgetState(#DG_PrefIsoSaves)
            ok = #True
            closed = #True
          Else
            MessageRequester("Could not save preferences", LastError$, #PB_MessageRequester_Error)
          EndIf
      EndSelect
    EndIf
  Until closed
  DisableWindow(#Win_Main, #False)
  CloseWindow(#Win_Prefs)
  SetActiveWindow(#Win_Main)
  ProcedureReturn ok
EndProcedure
