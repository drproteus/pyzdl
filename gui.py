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
            app.get_profile(profile_name).launch()

        button.Bind(wx.EVT_LEFT_UP, on_click)
        self.Show()

@click.command("pyzdl_gui")
@default_options
def main(app, config_path):
    gui = wx.App()
    frame = MainFrame(app)
    gui.MainLoop()


if __name__ == "__main__":
    main()
