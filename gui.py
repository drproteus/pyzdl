import wx
import click
from lib.util import default_options


class MainFrame(wx.Frame):
    def __init__(self, app):
        super().__init__(parent=None, title="pyZDL")

        choices = list(app.profiles.keys())
        profile_list = wx.ListBox(
            self,
            choices=choices,
            style=wx.LB_SINGLE,
            size=(140, 140),
        )
        run_button = wx.Button(self, label="Run", pos=(10, 190))

        profile_list.Selection = 0
        profile_name = choices[profile_list.Selection]
        profile = app.profiles.get(profile_name, None)
        info_box = wx.StaticText(
            self,
            label=profile.get_description(),
            pos=(140, 2),
            size=(254, 200),
        )

        def on_click(*args, **kwargs):
            profile_name = choices[profile_list.Selection]
            profile = app.profiles.get(profile_name, None)
            if not profile:
                raise click.ClickException(f"Could not find {profile_name} in config.")
            click.echo(f"Launching {profile_name}")
            profile.launch()

        def on_update(*args, **kwargs):
            profile_name = choices[profile_list.Selection]
            profile = app.profiles.get(profile_name, None)
            info_box.Label = profile.get_description()

        run_button.Bind(wx.EVT_LEFT_UP, on_click)
        profile_list.Bind(wx.EVT_TEXT_ENTER, on_click)
        profile_list.Bind(wx.EVT_LISTBOX, on_update)
        profile_list.Bind(wx.EVT_LISTBOX_DCLICK, on_click)
        self.Show()


@click.command("pyzdl_gui")
@default_options
def main(app, config_path):
    click.echo(f"Loading config from {config_path}", err=True)
    click.echo("Available profiles:")
    for name, _ in app.profiles.items():
        click.echo(f"* {name}", err=True)
    gui = wx.App()
    frame = MainFrame(app)
    gui.MainLoop()


if __name__ == "__main__":
    main()
