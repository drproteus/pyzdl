import wx
import os
import click
from lib.util import default_options, setup


class MainFrame(wx.Frame):
    def __init__(self, app, config_path):
        super().__init__(parent=None, title="pyZDL")
        self.app = app
        self.config_path = config_path
        self.dirname = "."
        self.control = wx.TextCtrl(self, style=wx.TE_MULTILINE)
        self.CreateStatusBar()
        filemenu = wx.Menu()
        menu_open = filemenu.Append(wx.ID_OPEN, "&Open", " Open a ZDL")
        menu_about = filemenu.Append(
            wx.ID_ABOUT, "&About", " Information about this program"
        )
        menu_exit = filemenu.Append(wx.ID_EXIT, "&Exit", " Terminate the program")
        menu_load_config = filemenu.Append(wx.ID_FILE1, "&Load", " Load new config")
        menu_reload = filemenu.Append(wx.ID_FILE2, "&Reload", " Reload config")

        menuBar = wx.MenuBar()
        menuBar.Append(filemenu, "&File")
        self.SetMenuBar(menuBar)

        self.choices = list(app.profiles.keys())
        self.profile_list = wx.ListBox(
            self,
            choices=self.choices,
            style=wx.LB_SINGLE,
            size=(140, 140),
        )
        self.run_button = wx.Button(self, label="Run", pos=(10, 190))

        self.profile_list.Selection = 0
        profile_name = self.choices[self.profile_list.Selection]
        profile = app.profiles.get(profile_name, None)

        self.info_box = wx.StaticText(
            self,
            label=profile.get_description(),
            pos=(140, 2),
            size=(254, 200),
        )

        self.args_box = wx.TextCtrl(
            self,
            value=profile.args or "",
            pos=(100, 190),
            size=(190, 20),
        )

        self.Bind(wx.EVT_MENU, self.on_about, menu_about)
        self.Bind(wx.EVT_MENU, self.on_open, menu_open)
        self.Bind(wx.EVT_MENU, self.on_load_config, menu_load_config)
        self.Bind(wx.EVT_MENU, self.on_reload, menu_reload)
        self.run_button.Bind(wx.EVT_LEFT_UP, self.on_click)
        self.profile_list.Bind(wx.EVT_TEXT_ENTER, self.on_click)
        self.profile_list.Bind(wx.EVT_LISTBOX, self.on_update)
        self.profile_list.Bind(wx.EVT_LISTBOX_DCLICK, self.on_click)
        self.args_box.Bind(wx.EVT_TEXT, self.on_args_edit)
        self.Show()

    def get_selected_profile(self):
        profile_name = self.choices[self.profile_list.Selection]
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
        self.info_box.Label = profile.get_description()
        self.args_box.Value = profile.args

    def on_args_edit(self, e):
        profile = self.get_selected_profile()
        profile.args = self.args_box.Value

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


@click.command("pyzdl_gui")
@default_options
def main(app, config_path):
    click.echo(f"Loading config from {config_path}", err=True)
    click.echo("Available profiles:")
    for name, _ in app.profiles.items():
        click.echo(f"* {name}", err=True)
    gui = wx.App()
    frame = MainFrame(app, config_path)
    gui.MainLoop()


if __name__ == "__main__":
    main()
