import wx
import click
from lib.util import default_options, setup


class MainFrame(wx.Frame):
    def __init__(self, app):
        super().__init__(parent=None, title="pyZDL")
        box = wx.ComboBox(self, choices=list(app.profiles.keys()))
        button = wx.Button(self, label="Run", pos=(0, 32))

        def on_click(*args, **kwargs):
            profile_name = box.Value
            profile = app.profiles.get(profile_name, None)
            if not profile:
                raise click.ClickException(f"Could not find {profile_name} in config.")
            click.echo(f"Launching {profile_name}")
            profile.launch()

        button.Bind(wx.EVT_LEFT_UP, on_click)
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
