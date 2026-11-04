import sys

import click
import wx

from lib.util import default_gui_options, setup
from wxui.main_frame import MainFrame


def run_gui(config_path, verbose=False):
    """Start the pyZDL graphical interface."""
    gui = wx.App(False)

    try:
        app = setup(config_path)
    except Exception as exc:
        wx.MessageBox(
            f"Could not load the configuration:\n\n{exc}",
            "pyZDL",
            wx.OK | wx.ICON_ERROR,
        )
        return

    if verbose:
        click.echo(f"Loading config from {config_path}", err=True)
        click.echo("Available profiles:", err=True)
        for name in app.profiles:
            click.echo(f"* {name}", err=True)

    MainFrame(app, config_path)
    gui.MainLoop()


@click.command("pyzdl_gui")
@default_gui_options
def main(config_path, verbose):
    """Start the pyZDL graphical interface."""
    run_gui(config_path, verbose)


if __name__ == "__main__":
    sys.exit(main())
