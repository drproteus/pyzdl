import wx
import wx.html2
import os
import click
import json
from lib.util import default_gui_options, setup, write_config, PYZDL_ROOT
from lib.models import Profile, Resource, Iwad, SourcePort
from wxglade.wxglade_out import (
    MainWindow,
    AddProfileDialogWindow,
    AddNamedResourceDialogWindow,
)
from jinja2 import Environment, FileSystemLoader, select_autoescape


base_dir = os.path.dirname(os.path.realpath(__file__))
print(base_dir)
env = Environment(
    loader=FileSystemLoader(os.path.join(base_dir, "templates")),
    autoescape=select_autoescape(),
)


def message_dialog(msg, title, parent=None):
    dialog = wx.MessageDialog(parent, msg, caption=title)
    dialog.ShowModal()
    dialog.Destroy()


def exception_dialog(exc, parent=None):
    message_dialog(str(exc), type(exc).__name__, parent=parent)


class BaseAddNamedResourceDialog(AddNamedResourceDialogWindow):
    def __init__(self, parent):
        super().__init__(parent=parent)
        self.dirname = parent.app.settings.pyzdl_root
        self.parent = parent
        self.app = parent.app
        self.add_named_resource_open_button.Bind(wx.EVT_LEFT_UP, self.on_file_add)
        self.add_named_resource_confirm_button.Bind(wx.EVT_LEFT_UP, self.on_confirm)
        self.cancel_add_named_resource_button.Bind(wx.EVT_LEFT_UP, self.on_cancel)

    def get_wildcard(self):
        return "*"

    def on_file_add(self, e):
        dialog = wx.FileDialog(
            self,
            "Choose a source port",
            self.dirname,
            "",
            self.get_wildcard(),
            wx.FD_OPEN,
        )
        if dialog.ShowModal() == wx.ID_OK:
            path = os.path.join(dialog.GetDirectory(), dialog.GetFilename())
            self.add_named_resource_file_path.Value = path
        dialog.Destroy()

    def on_confirm(self, e):
        raise NotImplementedError

    def on_cancel(self, e):
        self.Destroy()


class AddIwadDialog(BaseAddNamedResourceDialog):
    def __init__(self, parent, iwad=None):
        super().__init__(parent)
        self.dirname = self.parent.app.settings.doomwaddir
        self.SetTitle("Add IWAD")
        if iwad:
            self.add_named_resource_name.Value = iwad.name
            self.add_named_resource_file_path.Value = iwad.path
            self.SetTitle("Edit IWAD")

    def get_wildcard(self):
        return "*.wad;*.iwad;*.pk3;*.ipk3"

    def on_confirm(self, e):
        if (
            not self.add_named_resource_name.Value
            or not self.add_named_resource_file_path.Value
        ):
            return
        iwad = Iwad(
            name=self.add_named_resource_name.Value,
            file=Resource(path=self.add_named_resource_file_path.Value),
        )
        self.app.iwads[iwad.name] = iwad
        write_config(self.app, self.parent.config_path)
        self.parent.refresh()
        self.Destroy()


class AddSourcePortDialog(BaseAddNamedResourceDialog):
    def __init__(self, parent, port=None):
        super().__init__(parent)
        self.SetTitle("Add Source Port")
        if port:
            self.add_named_resource_nameValue = port.name
            self.add_named_resource_file_path.Value = port.executable.path
            self.SetTitle("Edit Source Port")

    def on_confirm(self, e):
        if (
            not self.add_named_resource_name.Value
            or not self.add_named_resource_file_path.Value
        ):
            return
        port = SourcePort(
            name=self.add_named_resource_name.Value,
            executable=Resource(path=self.add_named_resource_file_path.Value),
        )
        self.app.source_ports[port.name] = port
        write_config(self.app, self.parent.config_path)
        self.parent.refresh()
        self.Destroy()


class AddProfileDialog(AddProfileDialogWindow):
    def __init__(self, parent, profile=None):
        super().__init__(parent=parent)
        self.dirname = parent.app.settings.doomwaddir
        self.parent = parent
        self.app = parent.app
        self.profile = profile
        self.add_profile_iwad_choice_list.Clear()
        self.iwad_choices = []
        self.source_port_choices = []
        if self.profile:
            self.add_profile_name.Value = self.profile.name
        for i, (iwad_name, _) in enumerate(self.app.iwads.items()):
            self.iwad_choices.append(iwad_name)
            self.add_profile_iwad_choice_list.Append(iwad_name)
            if self.profile and self.profile.iwad.name == iwad_name:
                self.add_profile_iwad_choice_list.SetSelection(i)
        self.add_profile_source_port_choice_list.Clear()
        for i, (port_name, _) in enumerate(self.app.source_ports.items()):
            self.source_port_choices.append(port_name)
            self.add_profile_source_port_choice_list.Append(port_name)
            if self.profile and self.profile.port.name == port_name:
                self.add_profile_source_port_choice_list.SetSelection(i)
        self.filenames = []
        self.add_profile_files_list_box.Clear()
        if self.profile:
            self.SetTitle("Edit Profile")
            self.add_profile_args_box.Value = self.profile.args
        if self.profile and self.profile.files:
            for file in self.profile.files:
                self.add_profile_files_list_box.Append(file.path)
                self.filenames.append(file.path)
        self.confirm_add_profile_button.Bind(wx.EVT_LEFT_UP, self.on_confirm)
        self.add_profile_cancel_button.Bind(wx.EVT_LEFT_UP, self.on_cancel)
        self.remove_profile_file_button.Bind(wx.EVT_LEFT_UP, self.remove_file)
        self.add_profile_file_move_up_button.Bind(wx.EVT_LEFT_UP, self.move_file_up)
        self.add_profile_file_move_down_button.Bind(wx.EVT_LEFT_UP, self.move_file_down)
        self.add_profile_file_button.Bind(wx.EVT_LEFT_UP, self.on_file_add)
        self.Fit()

    def refresh_files(self):
        self.add_profile_files_list_box.Clear()
        for path in self.filenames:
            self.add_profile_files_list_box.Append(path)

    def on_confirm(self, e):
        if not self.add_profile_name.Value.strip():
            return
        profile = Profile(
            name=self.add_profile_name.Value,
            iwad=self.app.iwads[
                self.iwad_choices[self.add_profile_iwad_choice_list.Selection]
            ],
            port=self.app.source_ports[
                self.source_port_choices[
                    self.add_profile_source_port_choice_list.Selection
                ]
            ],
            files=[Resource(path=path) for path in self.filenames],
            args=self.add_profile_args_box.Value,
        )
        self.app.profiles[profile.name] = profile
        write_config(self.app, self.parent.config_path)
        self.parent.refresh()
        self.Destroy()

    def on_cancel(self, e):
        self.Destroy()

    def get_selected_filename(self):
        return self.add_profile_files_list_box.GetStringSelection()

    def remove_file(self, e):
        path = self.get_selected_filename()
        self.filenames.remove(path)
        self.refresh_files()

    def move_file_up(self, e):
        path = self.get_selected_filename()
        index = self.filenames.index(path)
        if len(self.filenames) < 2:
            return
        if index == 0:
            return
        self.filenames[index], self.filenames[index - 1] = (
            self.filenames[index - 1],
            self.filenames[index],
        )
        self.add_profile_files_list_box.SetSelection(index - 1)
        self.refresh_files()

    def move_file_down(self, e):
        path = self.get_selected_filename()
        index = self.filenames.index(path)
        if len(self.filenames) < 2:
            return
        if index == len(self.filenames) - 1:
            return
        self.filenames[index], self.filenames[index + 1] = (
            self.filenames[index + 1],
            self.filenames[index],
        )
        self.add_profile_files_list_box.SetSelection(index + 1)
        self.refresh_files()

    def on_file_add(self, e):
        dialog = wx.FileDialog(
            self,
            "Choose a file",
            self.dirname,
            "",
            "*.wad;*.iwad;*.pk3;*.pk3",
            wx.FD_OPEN | wx.FD_MULTIPLE,
        )
        if dialog.ShowModal() == wx.ID_OK:
            self.dirname = dialog.GetDirectory()
            for filename in dialog.GetFilenames():
                self.filenames.append(os.path.join(self.dirname, filename))
            self.refresh_files()
        dialog.Destroy()


class MainFrame(MainWindow):
    def __init__(self, app, config_path):
        super().__init__(parent=None, title="pyZDL")
        self.app = app
        self.choices = list(app.profiles.keys())
        self.config_path = config_path
        self.dirname = "."
        self.CreateStatusBar()
        filemenu = wx.Menu()
        menu_open = filemenu.Append(wx.ID_OPEN, "&Open", " Open a ZDL")
        menu_about = filemenu.Append(
            wx.ID_ABOUT, "&About", " Information about this program"
        )
        menu_exit = filemenu.Append(wx.ID_EXIT, "&Exit", " Terminate the program")
        menu_load_config = filemenu.Append(wx.ID_FILE1, "&Load", " Load new config")
        menu_reload = filemenu.Append(wx.ID_FILE2, "&Reload", " Reload config")
        menu_save = filemenu.Append(wx.ID_FILE3, "&Save", " Save config")
        filemenu.Append(wx.ID_FILE4, kind=wx.ITEM_SEPARATOR)
        menu_open_config_dir = filemenu.Append(
            wx.ID_FILE5, "&Config Folder", "Open Config Folder"
        )
        menu_open_doomwaddir = filemenu.Append(
            wx.ID_FILE6, "&DOOMWADDIR", "Open WADs Folder"
        )

        menuBar = wx.MenuBar()
        menuBar.Append(filemenu, "&File")
        self.SetMenuBar(menuBar)

        self.setup_profile_html_view()

        self.Bind(wx.EVT_MENU, self.on_about, menu_about)
        self.Bind(wx.EVT_MENU, self.on_open, menu_open)
        self.Bind(wx.EVT_MENU, self.on_load_config, menu_load_config)
        self.Bind(wx.EVT_MENU, self.on_reload, menu_reload)
        self.Bind(wx.EVT_MENU, self.on_save_config, menu_save)
        self.Bind(wx.EVT_MENU, self.on_open_config_dir, menu_open_config_dir)
        self.Bind(wx.EVT_MENU, self.on_open_doomwaddir, menu_open_doomwaddir)

        self.refresh_profiles(sort=True)
        self.profile_up_button.Hide()
        self.profile_down_button.Hide()

        self.iwads_list_box.Clear()
        for iwad_name, iwad in self.app.iwads.items():
            self.iwads_list_box.Append(iwad_name)

        self.source_ports_list_box.Clear()
        for port_name, port in self.app.source_ports.items():
            self.source_ports_list_box.Append(port_name)

        self.profile_saves_checkbox.SetValue(self.app.settings.profile_saves)
        self.profile_saves_checkbox.Bind(
            wx.EVT_CHECKBOX, self.update_settings_profile_saves
        )

        self.launch_button.Bind(wx.EVT_LEFT_UP, self.on_click)
        self.profiles_list_box.Bind(wx.EVT_TEXT_ENTER, self.on_click)
        self.profiles_list_box.Bind(wx.EVT_LISTBOX, self.on_update)
        self.profiles_list_box.Bind(wx.EVT_LISTBOX_DCLICK, self.on_click)
        self.args_box.Bind(wx.EVT_TEXT, self.on_args_edit)
        self.add_profile_button.Bind(wx.EVT_LEFT_UP, self.show_add_profile_dialog)
        self.edit_profile_button.Bind(wx.EVT_LEFT_UP, self.show_edit_profile_dialog)
        self.remove_profile_button.Bind(wx.EVT_LEFT_UP, self.remove_profile)
        self.add_iwad_button.Bind(wx.EVT_LEFT_UP, self.on_iwad_add)
        self.add_source_port_button.Bind(wx.EVT_LEFT_UP, self.on_source_port_add)
        self.remove_iwad_button.Bind(wx.EVT_LEFT_UP, self.on_iwad_remove)
        self.remove_source_port_button.Bind(wx.EVT_LEFT_UP, self.on_source_port_remove)
        self.edit_source_port_button.Bind(wx.EVT_LEFT_UP, self.on_source_port_edit)
        self.edit_iwad_button.Bind(wx.EVT_LEFT_UP, self.on_iwad_edit)
        self.profiles_list_box.Bind(wx.EVT_KEY_UP, self.handle_keypress)
        self.args_box.Bind(wx.EVT_KEY_UP, self.handle_keypress)
        if self.app.profiles:
            self.profiles_list_box.SetSelection(0)
        self.profiles_list_box.SetFocus()

        self.on_update(None)
        self.Show()

    def setup_profile_html_view(self):
        # Replace Profile HTML placeholder with actual WebView.
        # Can't simply subclass wx.html2.WebView, calling New is required.
        profile_html_view = wx.html2.WebView.New(
            parent=self.profile_html_view.Parent,
            id=self.profile_html_view.Id,
            pos=self.profile_html_view.Position,
            size=self.profile_html_view.Size,
            name=self.profile_html_view.Name,
        )
        self.sizer_7.Replace(self.profile_html_view, profile_html_view)
        self.profile_html_view = profile_html_view
        template = env.get_template("placeholder.html")
        self.profile_html_view.SetPage(template.render(), "")

    def refresh_profiles(self, sort=True, reverse=False):
        self.profiles_list_box.Clear()
        iter = self.app.profiles.keys()
        if sort:
            iter = sorted(iter, reverse=reverse)
        for profile_name in iter:
            self.profiles_list_box.Append(profile_name)

    def get_selected_profile(self):
        profile_name = self.profiles_list_box.GetStringSelection()
        profile = self.app.profiles.get(profile_name, None)
        return profile

    def launch_selected_profile(self):
        profile = self.get_selected_profile()
        if not profile:
            return
        write_config(self.app, self.config_path)
        self.app.launch_profile(profile.name)

    def on_click(self, e):
        self.launch_selected_profile()

    def on_update(self, e):
        profile = self.get_selected_profile()
        if not profile:
            return
        self.profile_name.Label = profile.name
        self.args_box.Value = profile.args
        self.update_profile_tree_view()

    def on_args_edit(self, e):
        profile = self.get_selected_profile()
        profile.args = self.args_box.Value
        self.update_profile_tree_view()

    def update_profile_tree_view(self):
        profile = self.get_selected_profile()
        # self.profile_tree_view.DeleteAllItems()
        # root = self.profile_tree_view.AddRoot(profile.port.name)
        # iwad = self.profile_tree_view.AppendItem(root, "IWAD")
        # self.profile_tree_view.AppendItem(iwad, profile.iwad.name)
        # files = self.profile_tree_view.AppendItem(root, "Files")
        # for file in profile.files:
        #     self.profile_tree_view.AppendItem(files, file.name)
        # if profile.args:
        #     args = self.profile_tree_view.AppendItem(root, "Extra")
        #     for arg in profile.args.split(" "):
        #         self.profile_tree_view.AppendItem(args, arg)
        # self.profile_tree_view.ExpandAll()
        template = env.get_template("profile.html")
        profile.image = profile.image or profile.get_cover_art()
        html = template.render(
            profile=profile,
            profile_json=json.dumps(profile.to_json(), indent=2),
            profile_args=profile.args.split(" ") if profile.args else [],
        )
        self.profile_html_view.SetPage(html, "/")

    def on_about(self, e):
        dialog = wx.MessageDialog(self, "python GZDoom launcher", "About pyZDL", wx.OK)
        dialog.ShowModal()
        dialog.Destroy()

    def on_open(self, e):
        dialog = wx.FileDialog(
            self,
            "Choose a file",
            self.dirname,
            "",
            "*.ini;*.zdl",
            wx.FD_OPEN,
        )
        if dialog.ShowModal() == wx.ID_OK:
            self.filename = dialog.GetFilename()
            self.dirname = dialog.GetDirectory()
            profile = self.app.load_zdl(os.path.join(self.dirname, self.filename))
            profile.launch()
        dialog.Destroy()

    def refresh(self):
        current_tab = self.tabs.GetSelection()
        new_frame = MainFrame(self.app, self.config_path)
        new_frame.tabs.SetSelection(current_tab)
        new_frame.Show()
        self.Destroy()

    def reload(self, config_path):
        current_tab = self.tabs.GetSelection()
        try:
            app = setup(config_path)
        except Exception as e:
            exception_dialog(e)
            return
        new_frame = MainFrame(app, config_path)
        new_frame.tabs.SetSelection(current_tab)
        new_frame.Show()
        self.Destroy()

    def on_load_config(self, e):
        dialog = wx.FileDialog(
            self,
            "Choose a config file",
            self.dirname,
            "",
            "*.json;*.ini;*.zdl",
            wx.FD_OPEN,
        )
        if dialog.ShowModal() == wx.ID_OK:
            config_path = os.path.join(dialog.GetDirectory(), dialog.GetFilename())
            self.reload(config_path)
        dialog.Destroy()

    def on_reload(self, e):
        self.reload(self.config_path)

    def on_save_config(self, e):
        write_config(self.app, self.config_path)

    def show_add_profile_dialog(self, e):
        add_profile_dialog = AddProfileDialog(self)
        add_profile_dialog.Show()

    def show_edit_profile_dialog(self, e):
        edit_profile_dialog = AddProfileDialog(
            self, profile=self.get_selected_profile()
        )
        edit_profile_dialog.Show()

    def remove_profile(self, e):
        selected_profile_name = self.profiles_list_box.GetStringSelection()
        del self.app.profiles[selected_profile_name]
        write_config(self.app, self.config_path)
        self.refresh()

    def update_settings_profile_saves(self, e):
        self.app.settings.profile_saves = self.profile_saves_checkbox.GetValue()

    def on_source_port_add(self, e):
        dialog = AddSourcePortDialog(self)
        dialog.Show()

    def on_iwad_add(self, e):
        dialog = AddIwadDialog(self)
        dialog.Show()

    def on_source_port_remove(self, e):
        selected_port_name = self.source_ports_list_box.GetStringSelection()
        if selected_port_name not in self.app.source_ports:
            return
        del self.app.source_ports[selected_port_name]
        write_config(self.app, self.config_path)
        self.refresh()

    def on_iwad_remove(self, e):
        selected_iwad_name = self.iwads_list_box.GetStringSelection()
        if selected_iwad_name not in self.app.iwads:
            return
        del self.app.iwads[selected_iwad_name]
        write_config(self.app, self.config_path)
        self.refresh()

    def on_source_port_edit(self, e):
        selected_port_name = self.source_ports_list_box.GetStringSelection()
        if selected_port_name not in self.app.source_ports:
            return
        port = self.app.source_ports[selected_port_name]
        dialog = AddSourcePortDialog(self, port=port)
        dialog.Show()

    def on_iwad_edit(self, e):
        selected_iwad_name = self.iwads_list_box.GetStringSelection()
        if selected_iwad_name not in self.app.iwads:
            return
        iwad = self.app.iwads[selected_iwad_name]
        dialog = AddIwadDialog(self, iwad=iwad)
        dialog.Show()

    def handle_keypress(self, e):
        keycode = e.GetKeyCode()
        if keycode == wx.WXK_RETURN:
            self.launch_selected_profile()

    def on_open_config_dir(self, e):
        Resource(path=PYZDL_ROOT).open()

    def on_open_doomwaddir(self, e):
        Resource(path=self.app.settings.doomwaddir).open()


@click.command("pyzdl_gui")
@default_gui_options
def main(config_path, verbose):
    gui = wx.App()

    try:
        app = setup(config_path)
    except Exception as e:
        exception_dialog(e)
        return

    if verbose:
        click.echo(f"Loading config from {config_path}", err=True)
        click.echo("Available profiles:")
        for name, _ in app.profiles.items():
            click.echo(f"* {name}", err=True)

    frame = MainFrame(app, config_path)
    gui.MainLoop()


if __name__ == "__main__":
    main()
