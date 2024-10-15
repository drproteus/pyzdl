import wx
import os
import click
from lib.util import default_options, setup, write_config
from lib.models import Profile, Resource
from wxglade.wxglade_out import MainWindow, AddProfileDialogWindow


class AddProfileDialog(AddProfileDialogWindow):
    def __init__(self, parent, profile=None):
        super().__init__(parent=parent)
        self.dirname = "."
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
            "*.wad;*.pk3",
            wx.FD_OPEN,
        )
        if dialog.ShowModal() == wx.ID_OK:
            path = os.path.join(dialog.GetDirectory(), dialog.GetFilename())
            self.filenames.append(path)
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
        menu_save = filemenu.Append(
            wx.ID_FILE3, "&Save", " Save profile args to config"
        )

        menuBar = wx.MenuBar()
        menuBar.Append(filemenu, "&File")
        self.SetMenuBar(menuBar)

        self.Bind(wx.EVT_MENU, self.on_about, menu_about)
        self.Bind(wx.EVT_MENU, self.on_open, menu_open)
        self.Bind(wx.EVT_MENU, self.on_load_config, menu_load_config)
        self.Bind(wx.EVT_MENU, self.on_reload, menu_reload)
        self.Bind(wx.EVT_MENU, self.on_save_config, menu_save)

        self.profiles_list_box.Clear()
        for profile_name, profile in self.app.profiles.items():
            self.profiles_list_box.Append(profile_name)

        self.iwads_list_box.Clear()
        for iwad_name, iwad in self.app.iwads.items():
            self.iwads_list_box.Append(iwad_name)

        self.source_ports_list_box.Clear()
        for port_name, port in self.app.source_ports.items():
            self.source_ports_list_box.Append(port_name)

        self.launch_button.Bind(wx.EVT_LEFT_UP, self.on_click)
        self.profiles_list_box.Bind(wx.EVT_TEXT_ENTER, self.on_click)
        self.profiles_list_box.Bind(wx.EVT_LISTBOX, self.on_update)
        self.profiles_list_box.Bind(wx.EVT_LISTBOX_DCLICK, self.on_click)
        self.args_box.Bind(wx.EVT_TEXT, self.on_args_edit)
        self.add_profile_button.Bind(wx.EVT_LEFT_UP, self.show_add_profile_dialog)
        self.edit_profile_button.Bind(wx.EVT_LEFT_UP, self.show_edit_profile_dialog)
        self.remove_profile_button.Bind(wx.EVT_LEFT_UP, self.remove_profile)

        self.profiles_list_box.Selection = 0
        self.on_update(None)

        self.Show()

    def get_selected_profile(self):
        profile_name = self.choices[self.profiles_list_box.Selection]
        profile = self.app.profiles.get(profile_name, None)
        if not profile:
            raise click.ClickException(f"Could not find {profile_name} in config.")
        return profile

    def launch_selected_profile(self):
        profile = self.get_selected_profile()
        profile.launch()

    def on_click(self, e):
        self.launch_selected_profile()

    def on_update(self, e):
        profile = self.get_selected_profile()
        self.profile_name.Label = profile.name
        self.args_box.Value = profile.args
        self.update_profile_tree_view()

    def on_args_edit(self, e):
        profile = self.get_selected_profile()
        profile.args = self.args_box.Value
        self.update_profile_tree_view()

    def update_profile_tree_view(self):
        profile = self.get_selected_profile()
        self.profile_tree_view.DeleteAllItems()
        root = self.profile_tree_view.AddRoot(profile.port.name)
        iwad = self.profile_tree_view.AppendItem(root, "IWAD")
        self.profile_tree_view.AppendItem(iwad, profile.iwad.name)
        files = self.profile_tree_view.AppendItem(root, "Files")
        for file in profile.files:
            self.profile_tree_view.AppendItem(files, file.name)
        if profile.args:
            args = self.profile_tree_view.AppendItem(root, "Extra")
            for arg in profile.args.split(" "):
                self.profile_tree_view.AppendItem(args, arg)
        self.profile_tree_view.ExpandAll()

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
        new_frame = MainFrame(self.app, self.config_path)
        new_frame.Show()
        self.Destroy()

    def reload(self, config_path):
        app = setup(config_path)
        new_frame = MainFrame(app, config_path)
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
        self.refresh()


@click.command("pyzdl_gui")
@click.option("--verbose", "-v", is_flag=True, default=False)
@default_options
def main(app, config_path, verbose):
    if verbose:
        click.echo(f"Loading config from {config_path}", err=True)
        click.echo("Available profiles:")
        for name, _ in app.profiles.items():
            click.echo(f"* {name}", err=True)
    gui = wx.App()
    frame = MainFrame(app, config_path)
    gui.MainLoop()


if __name__ == "__main__":
    main()
