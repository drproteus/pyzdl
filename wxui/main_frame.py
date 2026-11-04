import copy
import os
import shutil
import threading
from typing import Optional

import wx

from lib.errors import LoaderError
from lib.launcher import build_launch_spec
from lib.models import Profile, Resource
from lib.util import setup, write_config
from wxui import theme
from wxui.dialogs import (
    NewProfileDialog,
    PreferencesDialog,
    browse_directory,
    browse_file,
)

WILDCARD_MOD = "Doom mods (*.wad;*.iwad;*.pk3;*.ipk3;*.zip;*.deh;*.bex)|*.wad;*.iwad;*.pk3;*.ipk3;*.zip;*.deh;*.bex|All files (*.*)|*.*"
WILDCARD_CONFIG = "Config files (*.ini)|*.ini|All files (*.*)|*.*"
WILDCARD_IMAGE = (
    "Images (*.png;*.jpg;*.jpeg;*.webp)|*.png;*.jpg;*.jpeg;*.webp|All files (*.*)|*.*"
)


class FileDropTarget(wx.FileDropTarget):
    def __init__(self, callback):
        super().__init__()
        self.callback = callback

    def OnDropFiles(self, x, y, filenames):
        self.callback(filenames)
        return True


class ProfileSidebar(wx.Panel):
    def __init__(self, parent, on_select, on_activate, on_new, on_duplicate, on_delete):
        super().__init__(parent)
        self.on_select = on_select
        self.on_activate = on_activate
        self.on_new = on_new
        self.on_duplicate = on_duplicate
        self.on_delete = on_delete
        self._names: list[str] = []
        self._profiles = []
        self._icon_cache: dict[str, int] = {}

        outer = wx.BoxSizer(wx.VERTICAL)

        header = wx.BoxSizer(wx.HORIZONTAL)
        title = wx.StaticText(self, label="Profiles")
        title.SetFont(theme.heading_font())
        header.Add(title, 0, wx.ALIGN_CENTER_VERTICAL)
        header.AddStretchSpacer()
        self.count = wx.StaticText(self, label="0")
        self.count.SetForegroundColour(
            wx.SystemSettings.GetColour(wx.SYS_COLOUR_GRAYTEXT)
        )
        header.Add(self.count, 0, wx.ALIGN_CENTER_VERTICAL)
        outer.Add(header, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.TOP, 12)

        self.search = wx.SearchCtrl(self, style=wx.TE_PROCESS_ENTER)
        self.search.SetDescriptiveText("Search profiles…")
        self.search.ShowCancelButton(True)
        self.search.Bind(wx.EVT_TEXT, self.on_search)
        outer.Add(self.search, 0, wx.EXPAND | wx.ALL, 10)

        self.images = wx.ImageList(24, 24, True)
        self.images.Add(theme.bitmap_from_path(theme.DEFAULT_COVER, (24, 24)))
        self.list = wx.ListCtrl(
            self,
            style=wx.LC_REPORT | wx.LC_SINGLE_SEL | wx.LC_NO_HEADER | wx.BORDER_NONE,
        )
        self.list.AssignImageList(self.images, wx.IMAGE_LIST_SMALL)
        self.list.InsertColumn(0, "Profile", width=250)
        self.list.Bind(wx.EVT_LIST_ITEM_SELECTED, self.on_item_selected)
        self.list.Bind(wx.EVT_LIST_ITEM_ACTIVATED, self.on_item_activated)
        self.list.Bind(wx.EVT_LIST_KEY_DOWN, self.on_key_down)
        self.list.Bind(wx.EVT_SIZE, self.on_size)
        outer.Add(self.list, 1, wx.EXPAND | wx.LEFT | wx.RIGHT, 4)

        buttons = wx.BoxSizer(wx.HORIZONTAL)
        new_button = wx.Button(self, label="New")
        new_button.Bind(wx.EVT_BUTTON, lambda event: self.on_new())
        duplicate_button = wx.Button(self, label="Duplicate")
        duplicate_button.Bind(wx.EVT_BUTTON, lambda event: self.on_duplicate())
        delete_button = wx.Button(self, label="Delete")
        delete_button.Bind(wx.EVT_BUTTON, lambda event: self.on_delete())
        buttons.Add(new_button, 0, wx.RIGHT, 6)
        buttons.Add(duplicate_button, 0, wx.RIGHT, 6)
        buttons.AddStretchSpacer()
        buttons.Add(delete_button, 0)
        outer.Add(buttons, 0, wx.EXPAND | wx.ALL, 10)

        self.SetSizer(outer)

    def on_size(self, event):
        width = max(100, self.list.GetClientSize().width - 4)
        self.list.SetColumnWidth(0, width)
        event.Skip()

    def on_search(self, event):
        self.refresh(self._profiles, self.get_selected_name())

    def on_item_selected(self, event):
        self.on_select(self.get_selected_name())

    def on_item_activated(self, event):
        self.on_activate(self.get_selected_name())

    def on_key_down(self, event):
        if event.GetKeyCode() == wx.WXK_DELETE:
            self.on_delete()
        else:
            event.Skip()

    def get_selected_name(self) -> str:
        index = self.list.GetFirstSelected()
        if index < 0:
            return ""
        return self.list.GetItemText(index)

    def _icon_for(self, profile) -> int:
        image = profile.image or profile.get_cover_art()
        key = image.resolved_path if image else ""
        if not key:
            return 0
        if key in self._icon_cache:
            return self._icon_cache[key]
        index = self.images.Add(theme.small_icon(profile))
        self._icon_cache[key] = index
        return index

    def refresh(self, profiles, selected: str = ""):
        query = self.search.GetValue().strip().lower()
        self._profiles = list(profiles)
        self._names = sorted(
            (
                profile.name
                for profile in self._profiles
                if not query or query in profile.name.lower()
            ),
            key=str.casefold,
        )
        by_name = {profile.name: profile for profile in self._profiles}
        self.list.Freeze()
        self.list.DeleteAllItems()
        for name in self._names:
            self.list.InsertItem(
                self.list.GetItemCount(),
                name,
                self._icon_for(by_name[name]),
            )
        self.list.Thaw()
        self.count.SetLabel(str(len(self._names)))
        if selected and selected in self._names:
            self.select(selected)
        elif self._names:
            self.select(self._names[0])
        else:
            self.on_select("")
        self.Layout()

    def select(self, name: str):
        for index in range(self.list.GetItemCount()):
            if self.list.GetItemText(index) == name:
                self.list.Select(index)
                self.list.EnsureVisible(index)
                self.list.Focus(index)
                self.on_select(name)
                return
        self.on_select("")

    def clear(self):
        self._profiles = []
        self._names = []
        self.list.DeleteAllItems()
        self.count.SetLabel("0")
        self.on_select("")


class ProfileDetailPanel(wx.ScrolledWindow):
    def __init__(self, parent, app, on_change, on_launch, on_save):
        super().__init__(parent, style=wx.BORDER_NONE)
        self.app = app
        self.profile: Optional[Profile] = None
        self._loading = False
        self._files: list[Resource] = []
        self._checkboxes = hasattr(wx.ListCtrl, "EnableCheckBoxes")
        self.on_change = on_change
        self.on_launch = on_launch
        self.on_save = on_save

        self.SetScrollRate(0, 12)
        outer = wx.BoxSizer(wx.VERTICAL)

        # Header ---------------------------------------------------------
        header = wx.BoxSizer(wx.HORIZONTAL)
        self.cover = wx.StaticBitmap(
            self,
            bitmap=theme.bitmap_from_path(theme.DEFAULT_COVER, (150, 190)),
        )
        header.Add(self.cover, 0, wx.RIGHT | wx.ALIGN_TOP, 16)

        header_right = wx.BoxSizer(wx.VERTICAL)
        self.name = wx.TextCtrl(self, style=wx.TE_PROCESS_ENTER)
        self.name.SetFont(theme.title_font())
        self.name.SetHint("Profile name")
        self.name.Bind(wx.EVT_TEXT, lambda event: self._changed(name_changed=True))
        self.name.Bind(wx.EVT_TEXT_ENTER, lambda event: self.on_save())
        self.name.Bind(
            wx.EVT_KILL_FOCUS,
            lambda event: self._changed(name_changed=True, force=True),
        )
        header_right.Add(self.name, 0, wx.EXPAND | wx.BOTTOM, 4)

        self.meta = wx.StaticText(self, label="")
        self.meta.SetForegroundColour(
            wx.SystemSettings.GetColour(wx.SYS_COLOUR_GRAYTEXT)
        )
        header_right.Add(self.meta, 0, wx.BOTTOM, 10)

        choice_row = wx.BoxSizer(wx.HORIZONTAL)
        choice_row.Add(
            wx.StaticText(self, label="Port"), 0, wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 6
        )
        self.port = wx.Choice(self)
        self.port.Bind(wx.EVT_CHOICE, lambda event: self._changed())
        choice_row.Add(self.port, 1, wx.RIGHT, 14)
        choice_row.Add(
            wx.StaticText(self, label="IWAD"), 0, wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 6
        )
        self.iwad = wx.Choice(self)
        self.iwad.Bind(wx.EVT_CHOICE, lambda event: self._changed())
        choice_row.Add(self.iwad, 1)
        header_right.Add(choice_row, 0, wx.EXPAND | wx.BOTTOM, 10)

        actions = wx.BoxSizer(wx.HORIZONTAL)
        self.launch_button = wx.Button(self, label="▶  Launch")
        self.launch_button.SetFont(self.launch_button.GetFont().Bold())
        self.launch_button.Bind(wx.EVT_BUTTON, lambda event: self.on_launch())
        save_button = wx.Button(self, label="Save")
        save_button.Bind(wx.EVT_BUTTON, lambda event: self.on_save())
        cover_button = wx.Button(self, label="Set cover…")
        cover_button.Bind(wx.EVT_BUTTON, self.on_set_cover)
        open_button = wx.Button(self, label="Open folder")
        open_button.Bind(wx.EVT_BUTTON, self.on_open_folder)
        actions.Add(self.launch_button, 0, wx.RIGHT, 8)
        actions.Add(save_button, 0, wx.RIGHT, 8)
        actions.Add(cover_button, 0, wx.RIGHT, 8)
        actions.Add(open_button, 0)
        header_right.Add(actions, 0)
        header.Add(header_right, 1, wx.EXPAND)
        outer.Add(header, 0, wx.EXPAND | wx.ALL, 16)

        outer.Add(wx.StaticLine(self), 0, wx.EXPAND | wx.LEFT | wx.RIGHT, 16)

        # Load order -----------------------------------------------------
        outer.Add(self._section_label("Load order"), 0, wx.LEFT | wx.RIGHT | wx.TOP, 16)
        file_hint = wx.StaticText(
            self,
            label="Files are passed to the source port in this order. Drag files here to add them.",
        )
        file_hint.SetForegroundColour(
            wx.SystemSettings.GetColour(wx.SYS_COLOUR_GRAYTEXT)
        )
        outer.Add(file_hint, 0, wx.LEFT | wx.RIGHT | wx.BOTTOM, 16)

        self.files = wx.ListCtrl(
            self,
            style=wx.LC_REPORT | wx.LC_SINGLE_SEL | wx.BORDER_SIMPLE,
        )
        self.files.InsertColumn(0, "On", width=42)
        self.files.InsertColumn(1, "Mod", width=220)
        self.files.InsertColumn(2, "Path", width=360)
        self.files.Bind(wx.EVT_SIZE, self.on_files_size)
        if self._checkboxes:
            self.files.EnableCheckBoxes(True)
            bind = getattr(wx, "EVT_LIST_ITEM_CHECKED", None)
            if bind:
                self.files.Bind(bind, self.on_item_checked)
        self.files.SetDropTarget(FileDropTarget(self.add_dropped_files))
        self.files.Bind(wx.EVT_LEFT_UP, self.on_files_left_up)
        outer.Add(self.files, 0, wx.EXPAND | wx.LEFT | wx.RIGHT, 16)

        file_buttons = wx.BoxSizer(wx.HORIZONTAL)
        add_files_button = wx.Button(self, label="Add files…")
        add_files_button.Bind(wx.EVT_BUTTON, self.on_add_files)
        add_folder_button = wx.Button(self, label="Add folder…")
        add_folder_button.Bind(wx.EVT_BUTTON, self.on_add_folder)
        toggle_button = wx.Button(self, label="Enable / disable")
        toggle_button.Bind(wx.EVT_BUTTON, self.on_toggle_file)
        remove_button = wx.Button(self, label="Remove")
        remove_button.Bind(wx.EVT_BUTTON, self.on_remove_file)
        up_button = wx.Button(self, label="↑")
        up_button.SetMinSize((40, -1))
        up_button.Bind(wx.EVT_BUTTON, self.on_move_up)
        down_button = wx.Button(self, label="↓")
        down_button.SetMinSize((40, -1))
        down_button.Bind(wx.EVT_BUTTON, self.on_move_down)
        open_file_button = wx.Button(self, label="Open")
        open_file_button.Bind(wx.EVT_BUTTON, self.on_open_file)
        file_buttons.Add(add_files_button, 0, wx.RIGHT, 6)
        file_buttons.Add(add_folder_button, 0, wx.RIGHT, 6)
        file_buttons.Add(toggle_button, 0, wx.RIGHT, 6)
        file_buttons.Add(remove_button, 0, wx.RIGHT, 12)
        file_buttons.Add(up_button, 0, wx.RIGHT, 4)
        file_buttons.Add(down_button, 0, wx.RIGHT, 12)
        file_buttons.AddStretchSpacer()
        file_buttons.Add(open_file_button, 0)
        outer.Add(file_buttons, 0, wx.EXPAND | wx.ALL, 16)

        # Isolation ------------------------------------------------------
        box = wx.StaticBox(self, label="Config and saves")
        box_sizer = wx.StaticBoxSizer(box, wx.VERTICAL)

        self.config_mode = wx.Choice(
            self,
            choices=["Use global default", "Isolated", "Shared"],
        )
        self.config_mode.Bind(wx.EVT_CHOICE, lambda event: self._changed())
        box_sizer.Add(
            self._path_row(
                "Config",
                self.config_mode,
                "config_path",
                self.on_browse_config,
                self.on_open_config,
            ),
            0,
            wx.EXPAND | wx.ALL,
            8,
        )
        self.config_hint = wx.TextCtrl(
            self,
            style=wx.TE_READONLY | wx.TE_MULTILINE | wx.BORDER_NONE,
        )
        self.config_hint.SetMinSize((-1, 36))
        box_sizer.Add(
            self.config_hint, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 10
        )

        self.saves_mode = wx.Choice(
            self,
            choices=["Use global default", "Isolated", "Shared"],
        )
        self.saves_mode.Bind(wx.EVT_CHOICE, lambda event: self._changed())
        box_sizer.Add(
            self._path_row(
                "Saves",
                self.saves_mode,
                "saves_path",
                self.on_browse_saves,
                self.on_open_saves,
            ),
            0,
            wx.EXPAND | wx.ALL,
            8,
        )
        self.saves_hint = wx.TextCtrl(
            self,
            style=wx.TE_READONLY | wx.TE_MULTILINE | wx.BORDER_NONE,
        )
        self.saves_hint.SetMinSize((-1, 36))
        box_sizer.Add(
            self.saves_hint, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 10
        )

        self.workdir_path = wx.TextCtrl(self)
        workdir_row = wx.BoxSizer(wx.HORIZONTAL)
        workdir_row.Add(
            wx.StaticText(self, label="Working dir"),
            0,
            wx.ALIGN_CENTER_VERTICAL | wx.RIGHT,
            8,
        )
        workdir_row.Add(self.workdir_path, 1, wx.RIGHT, 8)
        workdir_browse = wx.Button(self, label="Browse…")
        workdir_browse.Bind(wx.EVT_BUTTON, self.on_browse_workdir)
        workdir_row.Add(workdir_browse, 0)
        self.workdir_path.Bind(wx.EVT_TEXT, lambda event: self._changed())
        box_sizer.Add(workdir_row, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 10)
        outer.Add(box_sizer, 0, wx.EXPAND | wx.LEFT | wx.RIGHT, 16)

        # Args and preview ----------------------------------------------
        outer.Add(
            self._section_label("Extra arguments"), 0, wx.LEFT | wx.RIGHT | wx.TOP, 16
        )
        self.args = wx.TextCtrl(self, style=wx.TE_MULTILINE)
        self.args.SetMinSize((-1, 54))
        self.args.SetFont(theme.mono_font())
        self.args.SetHint("-timedemo demo.lmp -skill 4")
        self.args.Bind(wx.EVT_TEXT, lambda event: self._changed())
        outer.Add(self.args, 0, wx.EXPAND | wx.LEFT | wx.RIGHT, 16)

        outer.Add(
            self._section_label("Command preview"), 0, wx.LEFT | wx.RIGHT | wx.TOP, 16
        )
        self.preview = wx.TextCtrl(
            self,
            style=wx.TE_MULTILINE | wx.TE_READONLY | wx.BORDER_SIMPLE,
        )
        self.preview.SetMinSize((-1, 76))
        self.preview.SetFont(theme.mono_font())
        outer.Add(self.preview, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 16)

        self.SetSizer(outer)
        self.FitInside()

    def on_files_size(self, event):
        width = max(200, self.files.GetClientSize().width)
        path_width = max(160, width - 42 - 220 - 8)
        self.files.SetColumnWidth(2, path_width)
        if event:
            event.Skip()

    def _section_label(self, text):
        label = wx.StaticText(self, label=text)
        label.SetFont(label.GetFont().Bold())
        return label

    def _path_row(self, label, mode_control, path_attr, browse_callback, open_callback):
        row = wx.BoxSizer(wx.HORIZONTAL)
        row.Add(
            wx.StaticText(self, label=label), 0, wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 8
        )
        row.Add(mode_control, 0, wx.RIGHT, 8)
        path = wx.TextCtrl(self)
        setattr(self, path_attr, path)
        path.SetHint("Default location")
        path.Bind(wx.EVT_TEXT, lambda event: self._changed())
        row.Add(path, 1, wx.RIGHT, 8)
        browse = wx.Button(self, label="Browse…")
        browse.Bind(wx.EVT_BUTTON, browse_callback)
        row.Add(browse, 0, wx.RIGHT, 6)
        open_button = wx.Button(self, label="Open")
        open_button.Bind(wx.EVT_BUTTON, open_callback)
        row.Add(open_button, 0)
        return row

    # Binding ------------------------------------------------------------
    def bind(self, profile: Optional[Profile]):
        self._loading = True
        self.profile = profile
        if profile is None:
            self.name.SetValue("")
            self.meta.SetLabel("")
            self.port.Set([])
            self.iwad.Set([])
            self._files = []
            self.refresh_files()
            self.args.SetValue("")
            self.config_path.SetValue("")
            self.saves_path.SetValue("")
            self.workdir_path.SetValue("")
            self.preview.SetValue("")
            self.cover.SetBitmap(
                theme.bitmap_from_path(theme.DEFAULT_COVER, (150, 190))
            )
            self._loading = False
            self.Enable(False)
            return
        self.Enable(True)
        self.name.SetValue(profile.name)
        self.cover.SetBitmap(theme.cover_bitmap(profile))
        self.port.Set(list(self.app.source_ports.keys()))
        port_names = list(self.app.source_ports.keys())
        self.port.SetSelection(
            port_names.index(profile.port.name)
            if profile.port.name in port_names
            else 0
        )
        self.iwad.Set(list(self.app.iwads.keys()))
        iwad_names = list(self.app.iwads.keys())
        self.iwad.SetSelection(
            iwad_names.index(profile.iwad.name)
            if profile.iwad.name in iwad_names
            else 0
        )
        self._files = list(profile.files or [])
        self.refresh_files()
        self.args.SetValue(profile.args or "")
        self._set_mode(self.config_mode, profile.isolate_config)
        self._set_mode(self.saves_mode, profile.isolate_saves)
        self.config_path.SetValue(profile.config.path if profile.config else "")
        self.saves_path.SetValue(profile.savedir.path if profile.savedir else "")
        self.workdir_path.SetValue(profile.workdir.path if profile.workdir else "")
        self._loading = False
        self.update_meta()
        self.update_hints()
        self.refresh_preview()

    def _set_mode(self, control, value):
        control.SetSelection(0 if value is None else 1 if value else 2)

    def _get_mode(self, control):
        selection = control.GetSelection()
        return None if selection <= 0 else True if selection == 1 else False

    def update_meta(self):
        if not self.profile:
            return
        mods = sum(1 for resource in self._files if resource.enabled)
        self.meta.SetLabel(
            f"{self.profile.port.name}  ·  {self.profile.iwad.name}  ·  "
            f"{mods} active mod{'s' if mods != 1 else ''}"
        )

    def update_hints(self):
        if not self.profile:
            return
        config_mode = self._get_mode(self.config_mode)
        if self.config_path.GetValue().strip():
            config_hint = f"Using custom config: {self.config_path.GetValue().strip()}"
        elif config_mode is True or (
            config_mode is None and self.app.settings.profile_configs
        ):
            config_hint = (
                f"Using profile config: {self.profile.get_default_config_path()}"
            )
        else:
            config_hint = "Using the source port's global config"
        saves_mode = self._get_mode(self.saves_mode)
        if self.saves_path.GetValue().strip():
            saves_hint = f"Using custom saves: {self.saves_path.GetValue().strip()}"
        elif saves_mode is True or (
            saves_mode is None and self.app.settings.profile_saves
        ):
            saves_hint = f"Using profile saves: {self.profile.get_savedir_path()}"
        else:
            saves_hint = "Using the source port's global save directory"
        self.config_hint.SetValue(config_hint)
        self.saves_hint.SetValue(saves_hint)

    def refresh_files(self):
        self.files.Freeze()
        self.files.DeleteAllItems()
        for index, resource in enumerate(self._files):
            self.files.InsertItem(index, "")
            self.files.SetItem(index, 1, resource.name)
            self.files.SetItem(index, 2, resource.path)
            self.files.SetItemData(index, index)
            if self._checkboxes:
                self.files.CheckItem(index, resource.enabled)
            else:
                self.files.SetItem(index, 0, "☑" if resource.enabled else "☐")
        self.files.Thaw()
        self.update_meta()

    def collect(self) -> str:
        if not self.profile:
            return ""
        name = self.name.GetValue().strip()
        port_name = self.port.GetStringSelection()
        iwad_name = self.iwad.GetStringSelection()
        if port_name in self.app.source_ports:
            self.profile.port = self.app.source_ports[port_name]
        if iwad_name in self.app.iwads:
            self.profile.iwad = self.app.iwads[iwad_name]
        self.profile.files = self._files
        self.profile.args = self.args.GetValue()
        config_path = self.config_path.GetValue().strip()
        self.profile.config = Resource(path=config_path) if config_path else None
        saves_path = self.saves_path.GetValue().strip()
        self.profile.savedir = Resource(path=saves_path) if saves_path else None
        workdir = self.workdir_path.GetValue().strip()
        self.profile.workdir = Resource(path=workdir) if workdir else None
        self.profile.isolate_config = self._get_mode(self.config_mode)
        self.profile.isolate_saves = self._get_mode(self.saves_mode)
        return name

    def refresh_preview(self):
        if not self.profile:
            self.preview.SetValue("")
            return
        try:
            spec = build_launch_spec(self.profile, self.app.settings)
            self.preview.SetValue(spec.command_preview())
        except LoaderError as exc:
            self.preview.SetValue(f"⚠ {exc}")

    def _changed(self, name_changed=False, force=False):
        if self._loading or not self.profile:
            return
        self.collect()
        self.update_meta()
        self.update_hints()
        self.refresh_preview()
        self.on_change(name_changed=name_changed, force=force)

    # File list actions -------------------------------------------------
    def _append_files(self, paths):
        for path in paths:
            path = os.path.abspath(path)
            if path not in [resource.path for resource in self._files]:
                self._files.append(Resource(path=path))
        self.refresh_files()
        self._changed()

    def add_dropped_files(self, filenames):
        self._append_files(filenames)

    def on_add_files(self, event):
        dialog = wx.FileDialog(
            self,
            "Add files",
            defaultDir=self.app.settings.doomwaddir,
            wildcard=WILDCARD_MOD,
            style=wx.FD_OPEN | wx.FD_FILE_MUST_EXIST | wx.FD_MULTIPLE,
        )
        if dialog.ShowModal() == wx.ID_OK:
            self._append_files(dialog.GetPaths())
        dialog.Destroy()

    def on_add_folder(self, event):
        path = browse_directory(self, self.app.settings.doomwaddir, "Add a folder")
        if path:
            self._append_files([path])

    def _selected_file_index(self) -> int:
        return self.files.GetFirstSelected()

    def on_item_checked(self, event):
        if self._loading:
            return
        index = event.GetIndex()
        if 0 <= index < len(self._files):
            self._files[index].enabled = self.files.IsItemChecked(index)
            self._changed()

    def on_files_left_up(self, event):
        event.Skip()
        if self._checkboxes:
            wx.CallAfter(self.sync_checkboxes)

    def sync_checkboxes(self):
        if self._loading or not self._checkboxes:
            return
        changed = False
        for index, resource in enumerate(self._files):
            checked = self.files.IsItemChecked(index)
            if resource.enabled != checked:
                resource.enabled = checked
                changed = True
        if changed:
            self._changed()

    def on_toggle_file(self, event):
        index = self._selected_file_index()
        if 0 <= index < len(self._files):
            self._files[index].enabled = not self._files[index].enabled
            self.refresh_files()
            self.files.Select(index)
            self._changed()

    def on_remove_file(self, event):
        index = self._selected_file_index()
        if 0 <= index < len(self._files):
            del self._files[index]
            self.refresh_files()
            if self._files:
                self.files.Select(min(index, len(self._files) - 1))
            self._changed()

    def on_move_up(self, event):
        index = self._selected_file_index()
        if index > 0:
            self._files[index - 1], self._files[index] = (
                self._files[index],
                self._files[index - 1],
            )
            self.refresh_files()
            self.files.Select(index - 1)
            self._changed()

    def on_move_down(self, event):
        index = self._selected_file_index()
        if 0 <= index < len(self._files) - 1:
            self._files[index + 1], self._files[index] = (
                self._files[index],
                self._files[index + 1],
            )
            self.refresh_files()
            self.files.Select(index + 1)
            self._changed()

    def on_open_file(self, event):
        index = self._selected_file_index()
        if 0 <= index < len(self._files):
            Resource(path=self._files[index].path).open()

    # Isolation actions -------------------------------------------------
    def on_browse_config(self, event):
        result = browse_file(
            self, self.config_path.GetValue(), "Choose a GZDoom config", WILDCARD_CONFIG
        )
        if result:
            self.config_path.SetValue(result)
            self._changed()

    def on_browse_saves(self, event):
        result = browse_directory(
            self, self.saves_path.GetValue(), "Choose a save folder"
        )
        if result:
            self.saves_path.SetValue(result)
            self._changed()

    def on_browse_workdir(self, event):
        result = browse_directory(
            self, self.workdir_path.GetValue(), "Choose a working directory"
        )
        if result:
            self.workdir_path.SetValue(result)
            self._changed()

    def on_open_config(self, event):
        path = self.config_path.GetValue().strip() or (
            self.profile.get_default_config_path() if self.profile else ""
        )
        if path:
            directory = path if os.path.isdir(path) else os.path.dirname(path)
            os.makedirs(directory, exist_ok=True)
            Resource(path=directory).open()

    def on_open_saves(self, event):
        path = self.saves_path.GetValue().strip() or (
            self.profile.get_savedir_path() if self.profile else ""
        )
        if path:
            os.makedirs(path, exist_ok=True)
            Resource(path=path).open()

    def on_set_cover(self, event):
        if not self.profile:
            return
        dialog = wx.FileDialog(
            self,
            "Choose cover art",
            wildcard=WILDCARD_IMAGE,
            style=wx.FD_OPEN | wx.FD_FILE_MUST_EXIST,
        )
        if dialog.ShowModal() == wx.ID_OK:
            source = dialog.GetPath()
            os.makedirs(self.profile.get_profile_path(), exist_ok=True)
            extension = os.path.splitext(source)[1].lower() or ".png"
            destination = os.path.join(
                self.profile.get_profile_path(), f"cover{extension}"
            )
            if os.path.abspath(source) != os.path.abspath(destination):
                shutil.copyfile(source, destination)
            self.profile.image = Resource(path=destination)
            self.cover.SetBitmap(theme.cover_bitmap(self.profile))
            self._changed()
        dialog.Destroy()

    def on_open_folder(self, event):
        if not self.profile:
            return
        path = self.profile.get_profile_path()
        os.makedirs(path, exist_ok=True)
        Resource(path=path).open()


class MainFrame(wx.Frame):
    def __init__(self, app, config_path):
        super().__init__(None, title="pyZDL")
        self.app = app
        self.config_path = config_path
        self._selected_name = ""
        self._autosave = None
        self._processes: list = []
        self._selecting = False

        self.SetMinSize((900, 640))
        self.SetSize(self._restore_geometry())
        self._restore_position()
        if theme.app_icon().IsOk():
            self.SetIcon(theme.app_icon())

        self._build_menu()
        self._build_ui()
        self._build_status_bar()
        self.refresh_profiles(select=self.app.settings.ui.get("selected_profile", ""))
        self.Bind(wx.EVT_CLOSE, self.on_close)
        if not self.app.settings.ui.get("geometry"):
            self.CentreOnScreen()
        self.Show()

    # Menus --------------------------------------------------------------
    def _build_menu(self):
        menu_bar = wx.MenuBar()
        file_menu = wx.Menu()
        new_profile = file_menu.Append(wx.ID_NEW, "New profile\tCtrl+N")
        open_zdl = file_menu.Append(wx.ID_OPEN, "Open ZDL…\tCtrl+O")
        import_profile = file_menu.Append(wx.NewIdRef(), "Import profile…")
        file_menu.AppendSeparator()
        save = file_menu.Append(wx.ID_SAVE, "Save\tCtrl+S")
        reload = file_menu.Append(wx.NewIdRef(), "Reload from disk\tF5")
        open_config = file_menu.Append(wx.NewIdRef(), "Open config…")
        file_menu.AppendSeparator()
        open_config_dir = file_menu.Append(wx.NewIdRef(), "Open config folder")
        open_wad_dir = file_menu.Append(wx.NewIdRef(), "Open WAD folder")
        file_menu.AppendSeparator()
        quit_item = file_menu.Append(wx.ID_EXIT, "Quit\tCtrl+Q")
        menu_bar.Append(file_menu, "&File")

        profile_menu = wx.Menu()
        launch = profile_menu.Append(wx.ID_EXECUTE, "Launch\tCtrl+L")
        duplicate = profile_menu.Append(wx.NewIdRef(), "Duplicate")
        delete = profile_menu.Append(wx.ID_DELETE, "Delete")
        profile_menu.AppendSeparator()
        open_profile_dir = profile_menu.Append(wx.NewIdRef(), "Open profile folder")
        menu_bar.Append(profile_menu, "&Profile")

        tools_menu = wx.Menu()
        preferences = tools_menu.Append(wx.ID_PREFERENCES, "Preferences…\tCtrl+,")
        validate = tools_menu.Append(wx.NewIdRef(), "Validate profiles")
        menu_bar.Append(tools_menu, "&Tools")

        help_menu = wx.Menu()
        about = help_menu.Append(wx.ID_ABOUT, "About pyZDL")
        menu_bar.Append(help_menu, "&Help")

        self.SetMenuBar(menu_bar)
        self.Bind(wx.EVT_MENU, lambda event: self.new_profile(), new_profile)
        self.Bind(wx.EVT_MENU, lambda event: self.open_zdl(), open_zdl)
        self.Bind(wx.EVT_MENU, lambda event: self.import_profile(), import_profile)
        self.Bind(wx.EVT_MENU, lambda event: self.save_current(force=True), save)
        self.Bind(wx.EVT_MENU, lambda event: self.reload_config(), reload)
        self.Bind(wx.EVT_MENU, lambda event: self.choose_config(), open_config)
        self.Bind(wx.EVT_MENU, lambda event: self.open_config_folder(), open_config_dir)
        self.Bind(wx.EVT_MENU, lambda event: self.open_wad_folder(), open_wad_dir)
        self.Bind(wx.EVT_MENU, lambda event: self.Close(), quit_item)
        self.Bind(wx.EVT_MENU, lambda event: self.launch_current(), launch)
        self.Bind(wx.EVT_MENU, lambda event: self.duplicate_profile(), duplicate)
        self.Bind(wx.EVT_MENU, lambda event: self.delete_profile(), delete)
        self.Bind(
            wx.EVT_MENU, lambda event: self.open_profile_folder(), open_profile_dir
        )
        self.Bind(wx.EVT_MENU, lambda event: self.show_preferences(), preferences)
        self.Bind(wx.EVT_MENU, lambda event: self.validate_profiles(), validate)
        self.Bind(wx.EVT_MENU, lambda event: self.show_about(), about)

    # Layout -------------------------------------------------------------
    def _build_ui(self):
        outer = wx.BoxSizer(wx.VERTICAL)
        self.infobar = wx.InfoBar(self)
        outer.Add(self.infobar, 0, wx.EXPAND)

        self.splitter = wx.SplitterWindow(self, style=wx.SP_LIVE_UPDATE | wx.SP_3DSASH)
        self.splitter.SetMinimumPaneSize(250)
        self.splitter.SetSashGravity(0.0)

        self.sidebar = ProfileSidebar(
            self.splitter,
            on_select=self.on_profile_selected,
            on_activate=lambda name: self.launch_current(),
            on_new=self.new_profile,
            on_duplicate=self.duplicate_profile,
            on_delete=self.delete_profile,
        )
        self.detail = ProfileDetailPanel(
            self.splitter,
            self.app,
            on_change=self.on_detail_change,
            on_launch=self.launch_current,
            on_save=lambda: self.save_current(force=True),
        )
        self.splitter.SplitVertically(self.sidebar, self.detail, 300)
        sash = self.app.settings.ui.get("sash")
        if isinstance(sash, int) and sash > 200:
            self.splitter.SetSashPosition(sash)
        outer.Add(self.splitter, 1, wx.EXPAND)
        self.SetSizer(outer)

        self.detail.Enable(False)

    def _build_status_bar(self):
        self.CreateStatusBar(2)
        self.SetStatusWidths([-1, 280])
        self.SetStatusText("Ready")

    def _restore_geometry(self):
        geometry = self.app.settings.ui.get("geometry")
        if isinstance(geometry, list) and len(geometry) == 4:
            try:
                return wx.Size(int(geometry[2]), int(geometry[3]))
            except (TypeError, ValueError):
                pass
        return wx.Size(1100, 820)

    def _restore_position(self):
        geometry = self.app.settings.ui.get("geometry")
        if isinstance(geometry, list) and len(geometry) == 4:
            try:
                self.SetPosition(wx.Point(int(geometry[0]), int(geometry[1])))
            except (TypeError, ValueError):
                pass

    # Profiles -----------------------------------------------------------
    def refresh_profiles(self, select: str = ""):
        self.sidebar.refresh(list(self.app.profiles.values()), select)
        name = self.sidebar.get_selected_name()
        if not name:
            self._selected_name = ""
            self.detail.bind(None)
        elif name != self._selected_name or self.detail.profile is None:
            self.on_profile_selected(name)
        self.UpdateWindowUI()

    def on_profile_selected(self, name: str):
        if self._selecting:
            return
        if name == self._selected_name:
            return
        if self._selected_name and not self.save_current(force=True, show_errors=False):
            # The save failed (for example, a duplicate rename).  Put the
            # highlight back on the profile the detail pane still shows.
            self._selecting = True
            try:
                self.sidebar.select(self._selected_name)
            finally:
                self._selecting = False
            return
        self._selecting = True
        try:
            self._selected_name = name
            profile = self.app.profiles.get(name)
            self.detail.bind(profile)
            if profile:
                self.SetStatusText(f"{profile.port.name}  ·  {profile.iwad.name}", 1)
            else:
                self.SetStatusText("", 1)
        finally:
            self._selecting = False

    def on_detail_change(self, name_changed=False, force=False):
        self.SetStatusText("Editing…")
        if self._autosave:
            self._autosave.Stop()
        delay = 1200 if name_changed else 500
        self._autosave = wx.CallLater(delay, lambda: self.save_current(force=force))

    def save_current(self, force=False, show_errors=True) -> bool:
        if self._autosave:
            self._autosave.Stop()
        self._autosave = None
        old_name = self._selected_name
        profile = self.app.profiles.get(old_name)
        if not profile or not self.detail.profile:
            return True
        # Avoid renaming on every keystroke while the name field has focus.
        if not force and self.detail.name.HasFocus():
            try:
                self.detail.collect()
            except LoaderError:
                pass
            return True
        try:
            new_name = self.detail.collect()
            if not new_name:
                raise LoaderError("Profile name cannot be empty.")
            if new_name != old_name:
                if new_name in self.app.profiles:
                    raise LoaderError(f"A profile named {new_name!r} already exists.")
                self.app.rename_profile(old_name, new_name)
                self._selected_name = new_name
            write_config(self.app, self.config_path)
        except (LoaderError, OSError) as exc:
            self.SetStatusText("Could not save")
            if show_errors:
                self.infobar.ShowMessage(str(exc), wx.ICON_ERROR)
            return False
        self.SetStatusText("Saved")
        self.SetStatusText(
            f"{profile.port.name}  ·  {profile.iwad.name}",
            1,
        )
        if new_name != old_name:
            self.sidebar.refresh(list(self.app.profiles.values()), new_name)
        return True

    def new_profile(self):
        if not self.app.source_ports or not self.app.iwads:
            self.infobar.ShowMessage(
                "Add a source port and an IWAD in Preferences first.",
                wx.ICON_INFORMATION,
            )
            return
        if not self.save_current(force=True):
            return
        dialog = NewProfileDialog(self, self.app)
        if dialog.ShowModal() == wx.ID_OK:
            name, port_name, iwad_name = dialog.get_values()
            profile = Profile(
                name=name,
                port=self.app.source_ports[port_name],
                iwad=self.app.iwads[iwad_name],
                folder=self.app.unique_folder(name),
            )
            self.app.attach_profile(profile)
            self.app.profiles[name] = profile
            write_config(self.app, self.config_path)
            self.refresh_profiles(select=name)
        dialog.Destroy()

    def duplicate_profile(self):
        profile = self.app.profiles.get(self._selected_name)
        if not profile:
            return
        if not self.save_current(force=True):
            return
        clone = copy.deepcopy(profile)
        base = f"{profile.name} copy"
        name = base
        counter = 2
        while name in self.app.profiles:
            name = f"{base} {counter}"
            counter += 1
        clone.name = name
        clone.folder = self.app.unique_folder(name)
        clone.config = None
        clone.savedir = None
        self.app.attach_profile(clone)
        self.app.profiles[name] = clone
        write_config(self.app, self.config_path)
        self.refresh_profiles(select=name)

    def delete_profile(self):
        profile = self.app.profiles.get(self._selected_name)
        if not profile:
            return
        dialog = wx.MessageDialog(
            self,
            f"Delete the profile {profile.name!r}?",
            "Delete profile",
            wx.YES_NO | wx.NO_DEFAULT | wx.ICON_WARNING,
        )
        if dialog.ShowModal() == wx.ID_YES:
            self.app.profiles.pop(profile.name, None)
            write_config(self.app, self.config_path)
            self._selected_name = ""
            self.refresh_profiles()
        dialog.Destroy()

    # Launch -------------------------------------------------------------
    def launch_current(self):
        if not self.save_current(force=True):
            return
        profile = self.app.profiles.get(self._selected_name)
        if not profile:
            self.infobar.ShowMessage("Select a profile first.", wx.ICON_INFORMATION)
            return
        errors = self.app.validate_profile(profile)
        if errors:
            self.infobar.ShowMessage(errors[0], wx.ICON_ERROR)
            return
        try:
            process = self.app.launch_profile(profile)
        except (LoaderError, OSError) as exc:
            self.infobar.ShowMessage(str(exc), wx.ICON_ERROR)
            return
        self.infobar.ShowMessage(f"Launched {profile.name}", wx.ICON_INFORMATION)
        self.SetStatusText(f"Running: {profile.name}")
        self._track_process(process, profile.name)

    def _track_process(self, process, name):
        if process is None:
            return
        self._processes.append(process)

        def wait():
            code = process.wait()
            wx.CallAfter(self._process_finished, process, name, code)

        threading.Thread(target=wait, daemon=True).start()

    def _process_finished(self, process, name, code):
        if process in self._processes:
            self._processes.remove(process)
        self.SetStatusText(f"{name} exited ({code})")
        self.SetStatusText("", 1)

    def open_zdl(self):
        if not self.save_current(force=True):
            return
        dialog = wx.FileDialog(
            self,
            "Open a ZDL file",
            wildcard="ZDL files (*.zdl;*.ini)|*.zdl;*.ini|All files (*.*)|*.*",
            style=wx.FD_OPEN | wx.FD_FILE_MUST_EXIST,
        )
        if dialog.ShowModal() == wx.ID_OK:
            try:
                process = self.app.launch_zdl(dialog.GetPath())
            except (LoaderError, OSError) as exc:
                self.infobar.ShowMessage(str(exc), wx.ICON_ERROR)
            else:
                self.SetStatusText(f"Running: {dialog.GetFilename()}")
                self._track_process(process, dialog.GetFilename())
        dialog.Destroy()

    def import_profile(self):
        dialog = wx.FileDialog(
            self,
            "Import a profile",
            wildcard="Profiles (*.json;*.zdl;*.ini)|*.json;*.zdl;*.ini|All files (*.*)|*.*",
            style=wx.FD_OPEN | wx.FD_FILE_MUST_EXIST,
        )
        if dialog.ShowModal() == wx.ID_OK:
            try:
                profile = self.app.import_profile(dialog.GetPath())
                write_config(self.app, self.config_path)
                self.refresh_profiles(select=profile.name)
            except (LoaderError, ValueError, OSError) as exc:
                self.infobar.ShowMessage(str(exc), wx.ICON_ERROR)
        dialog.Destroy()

    # Dialogs ------------------------------------------------------------
    def show_preferences(self):
        if not self.save_current(force=True):
            return
        dialog = PreferencesDialog(self, self.app)
        if dialog.ShowModal() == wx.ID_OK:
            write_config(self.app, self.config_path)
            self.detail.bind(self.app.profiles.get(self._selected_name))
            self.sidebar.refresh(list(self.app.profiles.values()), self._selected_name)
            self.SetStatusText("Preferences saved")
        dialog.Destroy()

    def validate_profiles(self):
        errors = []
        for profile in self.app.profiles.values():
            for error in self.app.validate_profile(profile):
                errors.append(f"{profile.name}: {error}")
        if errors:
            wx.MessageBox(
                "\n".join(errors),
                "Profile validation",
                wx.OK | wx.ICON_WARNING,
                self,
            )
        else:
            self.infobar.ShowMessage("All profiles look valid.", wx.ICON_INFORMATION)

    def show_about(self):
        wx.MessageBox(
            "pyZDL\nA Python GZDoom profile launcher.",
            "About pyZDL",
            wx.OK | wx.ICON_INFORMATION,
            self,
        )

    def choose_config(self):
        if not self.save_current(force=True):
            return
        dialog = wx.FileDialog(
            self,
            "Choose a config file",
            wildcard=(
                "pyZDL configs (*.json;*.ini;*.zdl)|*.json;*.ini;*.zdl|"
                "All files (*.*)|*.*"
            ),
            style=wx.FD_OPEN | wx.FD_FILE_MUST_EXIST,
        )
        if dialog.ShowModal() == wx.ID_OK:
            self.load_config(dialog.GetPath())
        dialog.Destroy()

    def load_config(self, config_path):
        if self._autosave:
            self._autosave.Stop()
            self._autosave = None
        try:
            app = setup(config_path)
        except Exception as exc:
            self.infobar.ShowMessage(str(exc), wx.ICON_ERROR)
            return
        self.app = app
        self.config_path = config_path
        self.detail.app = app
        self._selected_name = ""
        self.refresh_profiles(select=app.settings.ui.get("selected_profile", ""))
        self.SetStatusText(f"Loaded {config_path}")

    def reload_config(self):
        self.load_config(self.config_path)

    def open_config_folder(self):
        Resource(path=self.app.settings.pyzdl_root).open()

    def open_wad_folder(self):
        path = self.app.settings.doomwaddir
        os.makedirs(path, exist_ok=True)
        Resource(path=path).open()

    def open_profile_folder(self):
        self.detail.on_open_folder(None)

    # Window lifecycle ---------------------------------------------------
    def _save_ui_state(self):
        position = self.GetPosition()
        size = self.GetSize()
        self.app.settings.ui["geometry"] = [
            position.x,
            position.y,
            size.width,
            size.height,
        ]
        self.app.settings.ui["selected_profile"] = self._selected_name
        if self.splitter:
            self.app.settings.ui["sash"] = self.splitter.GetSashPosition()

    def on_close(self, event):
        saved = self.save_current(force=True, show_errors=False)
        self._save_ui_state()
        if saved:
            try:
                write_config(self.app, self.config_path)
            except OSError:
                pass
        self.Destroy()
