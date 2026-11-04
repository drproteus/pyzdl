import os

import wx

from lib.config import expand_path
from lib.errors import LoaderError
from lib.models import Iwad, Resource, SourcePort

WILDCARD_DOOM = "Doom files (*.wad;*.iwad;*.pk3;*.ipk3;*.zip;*.deh;*.bex)|*.wad;*.iwad;*.pk3;*.ipk3;*.zip;*.deh;*.bex|All files (*.*)|*.*"


def browse_directory(parent, value="", title="Choose a folder") -> str:
    dialog = wx.DirDialog(
        parent,
        title,
        defaultPath=value or os.path.expanduser("~"),
        style=wx.DD_DEFAULT_STYLE | wx.DD_DIR_MUST_EXIST,
    )
    result = ""
    if dialog.ShowModal() == wx.ID_OK:
        result = dialog.GetPath()
    dialog.Destroy()
    return result


def browse_file(
    parent, value="", title="Choose a file", wildcard="All files (*.*)|*.*"
) -> str:
    default_dir = ""
    default_name = ""
    if value:
        value = os.path.expanduser(value)
        if os.path.isdir(value):
            default_dir = value
        else:
            default_dir = os.path.dirname(value)
            default_name = os.path.basename(value)
    dialog = wx.FileDialog(
        parent,
        title,
        defaultDir=default_dir or os.path.expanduser("~"),
        defaultFile=default_name,
        wildcard=wildcard,
        style=wx.FD_OPEN | wx.FD_FILE_MUST_EXIST,
    )
    result = ""
    if dialog.ShowModal() == wx.ID_OK:
        result = dialog.GetPath()
    dialog.Destroy()
    return result


class NamedResourceDialog(wx.Dialog):
    """Add or edit a named resource (source port or IWAD)."""

    def __init__(
        self,
        parent,
        title: str,
        name: str = "",
        path: str = "",
        wildcard: str = "All files (*.*)|*.*",
        path_label: str = "Path",
        initial_dir: str = "",
        allow_directory: bool = False,
    ):
        super().__init__(
            parent,
            title=title,
            style=wx.DEFAULT_DIALOG_STYLE | wx.RESIZE_BORDER,
        )
        self.wildcard = wildcard
        self.initial_dir = initial_dir
        self.allow_directory = allow_directory

        outer = wx.BoxSizer(wx.VERTICAL)
        grid = wx.FlexGridSizer(cols=2, vgap=10, hgap=10)
        grid.AddGrowableCol(1)

        grid.Add(
            wx.StaticText(self, label="Name"),
            0,
            wx.ALIGN_CENTER_VERTICAL,
        )
        self.name = wx.TextCtrl(self)
        self.name.SetValue(name)
        grid.Add(self.name, 1, wx.EXPAND)

        grid.Add(
            wx.StaticText(self, label=path_label),
            0,
            wx.ALIGN_CENTER_VERTICAL,
        )
        path_sizer = wx.BoxSizer(wx.HORIZONTAL)
        self.path = wx.TextCtrl(self)
        self.path.SetValue(path)
        path_sizer.Add(self.path, 1, wx.EXPAND | wx.RIGHT, 8)
        browse = wx.Button(self, label="Browse…")
        browse.Bind(wx.EVT_BUTTON, self.on_browse)
        path_sizer.Add(browse, 0)
        grid.Add(path_sizer, 1, wx.EXPAND)

        outer.Add(grid, 1, wx.EXPAND | wx.ALL, 16)

        buttons = wx.BoxSizer(wx.HORIZONTAL)
        buttons.AddStretchSpacer()
        cancel = wx.Button(self, wx.ID_CANCEL, "Cancel")
        ok = wx.Button(self, wx.ID_OK, "Save")
        ok.SetDefault()
        ok.Bind(wx.EVT_BUTTON, self.on_ok)
        buttons.Add(cancel, 0, wx.RIGHT, 8)
        buttons.Add(ok, 0)
        outer.Add(buttons, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 16)

        self.SetSizerAndFit(outer)
        self.SetMinSize((500, self.GetSize().height))
        self.name.SetFocus()
        if name:
            self.path.SetFocus()
        else:
            self.name.SetFocus()

    def on_browse(self, event):
        if self.allow_directory:
            result = browse_directory(self, self.path.GetValue(), "Choose a folder")
        else:
            result = browse_file(
                self,
                self.path.GetValue(),
                "Choose a file",
                self.wildcard,
            )
        if result:
            self.path.SetValue(result)

    def on_ok(self, event):
        name = self.name.GetValue().strip()
        path = self.path.GetValue().strip()
        if not name:
            wx.MessageBox(
                "Please enter a name.", "Invalid name", wx.OK | wx.ICON_WARNING, self
            )
            self.name.SetFocus()
            return
        if not path:
            wx.MessageBox(
                "Please choose a path.", "Invalid path", wx.OK | wx.ICON_WARNING, self
            )
            self.path.SetFocus()
            return
        if not os.path.exists(expand_path(path)):
            wx.MessageBox(
                f"Path does not exist:\n{path}",
                "Invalid path",
                wx.OK | wx.ICON_WARNING,
                self,
            )
            self.path.SetFocus()
            return
        self.EndModal(wx.ID_OK)

    def get_values(self) -> tuple[str, str]:
        return self.name.GetValue().strip(), self.path.GetValue().strip()


class NewProfileDialog(wx.Dialog):
    def __init__(self, parent, app):
        super().__init__(parent, title="New Profile", style=wx.DEFAULT_DIALOG_STYLE)
        self.app = app

        outer = wx.BoxSizer(wx.VERTICAL)
        grid = wx.FlexGridSizer(cols=2, vgap=10, hgap=10)
        grid.AddGrowableCol(1)

        grid.Add(wx.StaticText(self, label="Name"), 0, wx.ALIGN_CENTER_VERTICAL)
        self.name = wx.TextCtrl(self)
        grid.Add(self.name, 1, wx.EXPAND)

        grid.Add(wx.StaticText(self, label="Source port"), 0, wx.ALIGN_CENTER_VERTICAL)
        self.port = wx.Choice(self, choices=list(app.source_ports.keys()))
        if app.source_ports:
            self.port.SetSelection(0)
        grid.Add(self.port, 1, wx.EXPAND)

        grid.Add(wx.StaticText(self, label="IWAD"), 0, wx.ALIGN_CENTER_VERTICAL)
        self.iwad = wx.Choice(self, choices=list(app.iwads.keys()))
        if app.iwads:
            self.iwad.SetSelection(0)
        grid.Add(self.iwad, 1, wx.EXPAND)

        outer.Add(grid, 1, wx.EXPAND | wx.ALL, 16)

        buttons = wx.BoxSizer(wx.HORIZONTAL)
        buttons.AddStretchSpacer()
        cancel = wx.Button(self, wx.ID_CANCEL, "Cancel")
        ok = wx.Button(self, wx.ID_OK, "Create")
        ok.SetDefault()
        ok.Bind(wx.EVT_BUTTON, self.on_ok)
        buttons.Add(cancel, 0, wx.RIGHT, 8)
        buttons.Add(ok, 0)
        outer.Add(buttons, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 16)

        self.SetSizerAndFit(outer)
        self.SetMinSize((420, self.GetSize().height))
        self.name.SetFocus()

    def on_ok(self, event):
        name = self.name.GetValue().strip()
        if not name:
            wx.MessageBox(
                "Please enter a profile name.",
                "Invalid name",
                wx.OK | wx.ICON_WARNING,
                self,
            )
            return
        if name in self.app.profiles:
            wx.MessageBox(
                f"A profile named {name!r} already exists.",
                "Duplicate name",
                wx.OK | wx.ICON_WARNING,
                self,
            )
            return
        if self.port.GetSelection() < 0 or self.iwad.GetSelection() < 0:
            wx.MessageBox(
                "Add a source port and an IWAD first.",
                "Nothing to launch",
                wx.OK | wx.ICON_WARNING,
                self,
            )
            return
        self.EndModal(wx.ID_OK)

    def get_values(self) -> tuple[str, str, str]:
        return (
            self.name.GetValue().strip(),
            self.port.GetStringSelection(),
            self.iwad.GetStringSelection(),
        )


class ResourceListPanel(wx.Panel):
    def __init__(
        self, parent, entries, title, wildcard, path_label="Path", initial_dir=""
    ):
        super().__init__(parent)
        self.title = title
        self.wildcard = wildcard
        self.path_label = path_label
        self.initial_dir = initial_dir
        # Each entry is {"original": name|None, "name": name, "path": path}
        self.entries = [dict(entry) for entry in entries]

        outer = wx.BoxSizer(wx.VERTICAL)
        header = wx.StaticText(self, label=title)
        header.SetFont(header.GetFont().Bold())
        outer.Add(header, 0, wx.ALL, 10)
        self.list = wx.ListBox(self, style=wx.LB_SINGLE)
        outer.Add(self.list, 1, wx.EXPAND | wx.LEFT | wx.RIGHT, 10)

        buttons = wx.BoxSizer(wx.HORIZONTAL)
        add = wx.Button(self, label="Add…")
        edit = wx.Button(self, label="Edit…")
        remove = wx.Button(self, label="Remove")
        add.Bind(wx.EVT_BUTTON, self.on_add)
        edit.Bind(wx.EVT_BUTTON, self.on_edit)
        remove.Bind(wx.EVT_BUTTON, self.on_remove)
        buttons.Add(add, 0, wx.RIGHT, 8)
        buttons.Add(edit, 0, wx.RIGHT, 8)
        buttons.AddStretchSpacer()
        buttons.Add(remove, 0)
        outer.Add(buttons, 0, wx.EXPAND | wx.ALL, 10)
        self.SetSizer(outer)
        self.refresh()

    def refresh(self, select: int = -1):
        self.list.Set(
            [f"{entry['name']}  —  {entry['path']}" for entry in self.entries]
        )
        if 0 <= select < len(self.entries):
            self.list.SetSelection(select)

    def get_entries(self):
        return [dict(entry) for entry in self.entries]

    def on_add(self, event):
        dialog = NamedResourceDialog(
            self,
            f"Add {self.title}",
            wildcard=self.wildcard,
            path_label=self.path_label,
            initial_dir=self.initial_dir,
            allow_directory=self.path_label.lower().startswith("folder"),
        )
        if dialog.ShowModal() == wx.ID_OK:
            name, path = dialog.get_values()
            self.entries.append({"original": None, "name": name, "path": path})
            self.refresh(len(self.entries) - 1)
        dialog.Destroy()

    def on_edit(self, event):
        index = self.list.GetSelection()
        if index < 0:
            return
        entry = self.entries[index]
        dialog = NamedResourceDialog(
            self,
            f"Edit {self.title}",
            name=entry["name"],
            path=entry["path"],
            wildcard=self.wildcard,
            path_label=self.path_label,
            initial_dir=self.initial_dir,
            allow_directory=self.path_label.lower().startswith("folder"),
        )
        if dialog.ShowModal() == wx.ID_OK:
            entry["name"], entry["path"] = dialog.get_values()
            self.refresh(index)
        dialog.Destroy()

    def on_remove(self, event):
        index = self.list.GetSelection()
        if index < 0:
            return
        del self.entries[index]
        self.refresh(min(index, len(self.entries) - 1))


def _apply_resource_changes(app, kind: str, staged: list[dict]) -> None:
    """Apply a staged list of ports or IWADs, preserving profile references.

    Validation happens before anything is mutated, so a bad path or a resource
    that is still in use leaves the application untouched.
    """
    is_port = kind == "port"
    existing = app.source_ports if is_port else app.iwads
    used_by = app.profiles_using_port if is_port else app.profiles_using_iwad

    names = [entry["name"] for entry in staged]
    if any(not name for name in names):
        raise LoaderError("Every resource needs a name.")
    if len(set(names)) != len(names):
        raise LoaderError("Resource names must be unique.")

    for entry in staged:
        if not os.path.exists(expand_path(entry["path"], app.settings.pyzdl_root)):
            raise LoaderError(f"Path does not exist: {entry['path']}")

    originals = {entry["original"] for entry in staged if entry["original"]}
    for name in existing:
        if name in originals:
            continue
        profiles = used_by(name)
        if profiles:
            label = "source port" if is_port else "IWAD"
            raise LoaderError(
                f"Cannot remove {label} {name!r}; it is used by: {', '.join(profiles)}"
            )

    # The old objects are indexed by name so profiles that still point at a
    # stale copy (or that share the object) can be repointed to the new one.
    old_names = {id(obj): name for name, obj in existing.items()}
    final = {}
    replacement = {}
    for entry in staged:
        original = entry["original"]
        obj = (
            SourcePort(name=entry["name"], executable=Resource(path=entry["path"]))
            if is_port
            else Iwad(name=entry["name"], file=Resource(path=entry["path"]))
        )
        final[entry["name"]] = obj
        if original:
            replacement[original] = obj

    for profile in app.profiles.values():
        current = profile.port if is_port else profile.iwad
        old_name = old_names.get(id(current), current.name)
        target = replacement.get(old_name)
        if target is None:
            continue
        if is_port:
            profile.port = target
        else:
            profile.iwad = target

    existing.clear()
    existing.update(final)


class PreferencesDialog(wx.Dialog):
    def __init__(self, parent, app):
        super().__init__(
            parent,
            title="Preferences",
            style=wx.DEFAULT_DIALOG_STYLE | wx.RESIZE_BORDER,
        )
        self.app = app

        outer = wx.BoxSizer(wx.VERTICAL)
        notebook = wx.Notebook(self)
        notebook.AddPage(self._build_general_page(notebook), "General")
        notebook.AddPage(
            self._build_resources_page(
                notebook,
                "Source ports",
                [
                    {
                        "original": name,
                        "name": name,
                        "path": port.executable.path,
                    }
                    for name, port in app.source_ports.items()
                ],
                kind="port",
            ),
            "Source Ports",
        )
        notebook.AddPage(
            self._build_resources_page(
                notebook,
                "IWADs",
                [
                    {
                        "original": name,
                        "name": name,
                        "path": iwad.path,
                    }
                    for name, iwad in app.iwads.items()
                ],
                kind="iwad",
            ),
            "IWADs",
        )
        outer.Add(notebook, 1, wx.EXPAND | wx.ALL, 12)

        buttons = wx.BoxSizer(wx.HORIZONTAL)
        buttons.AddStretchSpacer()
        cancel = wx.Button(self, wx.ID_CANCEL, "Cancel")
        ok = wx.Button(self, wx.ID_OK, "Save")
        ok.SetDefault()
        ok.Bind(wx.EVT_BUTTON, self.on_ok)
        buttons.Add(cancel, 0, wx.RIGHT, 8)
        buttons.Add(ok, 0)
        outer.Add(buttons, 0, wx.EXPAND | wx.LEFT | wx.RIGHT | wx.BOTTOM, 12)

        self.SetSizerAndFit(outer)
        self.SetSize((640, 520))
        self.SetMinSize((560, 440))

    def _build_general_page(self, parent):
        page = wx.Panel(parent)
        outer = wx.BoxSizer(wx.VERTICAL)
        grid = wx.FlexGridSizer(cols=2, vgap=10, hgap=10)
        grid.AddGrowableCol(1)

        grid.Add(wx.StaticText(page, label="DOOMWADDIR"), 0, wx.ALIGN_CENTER_VERTICAL)
        wad_dir_sizer = wx.BoxSizer(wx.HORIZONTAL)
        self.doomwaddir = wx.TextCtrl(page)
        self.doomwaddir.SetValue(self.app.settings.doomwaddir)
        wad_dir_sizer.Add(self.doomwaddir, 1, wx.EXPAND | wx.RIGHT, 8)
        wad_dir_browse = wx.Button(page, label="Browse…")
        wad_dir_browse.Bind(wx.EVT_BUTTON, self.on_browse_waddir)
        wad_dir_sizer.Add(wad_dir_browse, 0)
        grid.Add(wad_dir_sizer, 1, wx.EXPAND)

        grid.Add(wx.StaticText(page, label="DOOMWADPATH"), 0, wx.ALIGN_CENTER_VERTICAL)
        self.doomwadpath = wx.TextCtrl(page)
        self.doomwadpath.SetValue(";".join(self.app.settings.doomwadpath or []))
        grid.Add(self.doomwadpath, 1, wx.EXPAND)

        grid.Add(
            wx.StaticText(page, label="Default GZDoom config"),
            0,
            wx.ALIGN_CENTER_VERTICAL,
        )
        config_sizer = wx.BoxSizer(wx.HORIZONTAL)
        self.default_config = wx.TextCtrl(page)
        self.default_config.SetValue(self.app.settings.default_config or "")
        self.default_config.SetHint("Uses defaults/gzdoom.ini in the config folder")
        config_sizer.Add(self.default_config, 1, wx.EXPAND | wx.RIGHT, 8)
        config_browse = wx.Button(page, label="Browse…")
        config_browse.Bind(wx.EVT_BUTTON, self.on_browse_default_config)
        config_sizer.Add(config_browse, 0)
        grid.Add(config_sizer, 1, wx.EXPAND)

        outer.Add(grid, 0, wx.EXPAND | wx.ALL, 16)

        self.profile_configs = wx.CheckBox(
            page, label="Isolate GZDoom config per profile by default"
        )
        self.profile_configs.SetValue(self.app.settings.profile_configs)
        outer.Add(self.profile_configs, 0, wx.LEFT | wx.RIGHT | wx.TOP, 16)

        self.profile_saves = wx.CheckBox(
            page, label="Isolate save games per profile by default"
        )
        self.profile_saves.SetValue(self.app.settings.profile_saves)
        outer.Add(self.profile_saves, 0, wx.LEFT | wx.RIGHT | wx.TOP, 16)

        hint = wx.StaticText(
            page,
            label=(
                "DOOMWADPATH entries are separated with ';'. "
                "Profiles can override config and save isolation individually."
            ),
        )
        hint.Wrap(560)
        outer.Add(hint, 0, wx.ALL, 16)
        page.SetSizer(outer)
        return page

    def _build_resources_page(self, parent, title, entries, kind):
        page = wx.Panel(parent)
        outer = wx.BoxSizer(wx.VERTICAL)
        wildcard = (
            "Applications (*.app)|*.app|All files (*.*)|*.*"
            if kind == "port"
            else WILDCARD_DOOM
        )
        panel = ResourceListPanel(
            page,
            entries,
            title,
            wildcard,
            path_label="Executable" if kind == "port" else "Path",
            initial_dir=self.app.settings.doomwaddir,
        )
        if kind == "port":
            self.ports_panel = panel
        else:
            self.iwads_panel = panel
        outer.Add(panel, 1, wx.EXPAND)
        page.SetSizer(outer)
        return page

    def on_browse_waddir(self, event):
        result = browse_directory(self, self.doomwaddir.GetValue(), "Choose DOOMWADDIR")
        if result:
            self.doomwaddir.SetValue(result)

    def on_browse_default_config(self, event):
        result = browse_file(
            self,
            self.default_config.GetValue(),
            "Choose a default GZDoom config",
            "Config files (*.ini)|*.ini|All files (*.*)|*.*",
        )
        if result:
            self.default_config.SetValue(result)

    def on_ok(self, event):
        try:
            self._apply()
        except LoaderError as exc:
            wx.MessageBox(
                str(exc), "Could not save preferences", wx.OK | wx.ICON_ERROR, self
            )
            return
        self.EndModal(wx.ID_OK)

    def _apply(self):
        _apply_resource_changes(self.app, "port", self.ports_panel.get_entries())
        _apply_resource_changes(self.app, "iwad", self.iwads_panel.get_entries())
        settings = self.app.settings
        settings.doomwaddir_override = self.doomwaddir.GetValue().strip() or None
        wadpath = self.doomwadpath.GetValue().strip()
        settings.doomwadpath_override = (
            [part for part in wadpath.replace(os.pathsep, ";").split(";") if part]
            if wadpath
            else None
        )
        settings.default_config = self.default_config.GetValue().strip() or None
        settings.profile_configs = self.profile_configs.GetValue()
        settings.profile_saves = self.profile_saves.GetValue()
