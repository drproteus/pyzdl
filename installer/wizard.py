"""Graphical setup window for the portable pyZDL install."""

import subprocess

import wx

from installer import install as core


class SetupFrame(wx.Frame):
    def __init__(self):
        super().__init__(None, title="pyZDL Setup", size=(560, 380))
        self.SetMinSize((560, 380))

        panel = wx.Panel(self)
        outer = wx.BoxSizer(wx.VERTICAL)

        heading = wx.StaticText(panel, label="Install pyZDL")
        font = heading.GetFont()
        font.SetPointSize(font.GetPointSize() + 4)
        font.MakeBold()
        heading.SetFont(font)
        outer.Add(heading, 0, wx.ALL, 16)

        form = wx.FlexGridSizer(cols=2, vgap=10, hgap=12)
        form.AddGrowableCol(1)
        form.Add(
            wx.StaticText(panel, label="Install folder:"), 0, wx.ALIGN_CENTER_VERTICAL
        )
        self.dir_picker = wx.DirPickerCtrl(
            panel,
            path=core.default_install_dir(),
            message="Choose the folder to install pyZDL into",
        )
        form.Add(self.dir_picker, 1, wx.EXPAND)
        outer.Add(form, 0, wx.EXPAND | wx.LEFT | wx.RIGHT, 16)

        options = wx.BoxSizer(wx.VERTICAL)
        self.scan_box = wx.CheckBox(
            panel, label="Find installed source ports (GZDoom, Chocolate Doom, ...)"
        )
        self.scan_box.SetValue(True)
        self.shortcut_box = wx.CheckBox(
            panel, label="Add a desktop shortcut (opens the GUI)"
        )
        self.shortcut_box.SetValue(True)
        self.launch_box = wx.CheckBox(panel, label="Launch pyZDL when setup finishes")
        for box in (self.scan_box, self.shortcut_box, self.launch_box):
            options.Add(box, 0, wx.BOTTOM, 8)
        outer.Add(options, 0, wx.ALL, 16)

        self.status = wx.StaticText(panel, label="")
        outer.Add(self.status, 0, wx.LEFT | wx.RIGHT, 16)
        outer.AddStretchSpacer()

        buttons = wx.BoxSizer(wx.HORIZONTAL)
        buttons.AddStretchSpacer()
        cancel = wx.Button(panel, wx.ID_CANCEL, "Cancel")
        install = wx.Button(panel, wx.ID_OK, "Install")
        install.SetDefault()
        buttons.Add(cancel, 0, wx.RIGHT, 8)
        buttons.Add(install, 0)
        outer.Add(buttons, 0, wx.EXPAND | wx.ALL, 16)

        panel.SetSizer(outer)
        install.Bind(wx.EVT_BUTTON, self.on_install)
        cancel.Bind(wx.EVT_BUTTON, lambda event: self.Close())

    def on_install(self, event):
        install_dir = self.dir_picker.GetPath()
        if not install_dir:
            wx.MessageBox(
                "Choose an install folder.", "pyZDL Setup", wx.OK | wx.ICON_WARNING
            )
            return
        self.status.SetLabel("Installing...")
        try:
            result = core.install(
                install_dir,
                desktop_shortcut=self.shortcut_box.GetValue(),
                scan_ports=self.scan_box.GetValue(),
            )
        except (OSError, subprocess.CalledProcessError) as exc:
            self.status.SetLabel("")
            wx.MessageBox(
                f"Setup could not finish:\n\n{exc}",
                "pyZDL Setup",
                wx.OK | wx.ICON_ERROR,
            )
            return

        if self.launch_box.GetValue():
            subprocess.Popen([result.exe_path, "gui"], cwd=install_dir)
        message = f"pyZDL was installed to:\n\n{install_dir}"
        if result.config_kept:
            message += "\n\nAn existing config.json was kept unchanged."
        elif self.scan_box.GetValue():
            found = ", ".join(result.added_ports) or "none"
            message += f"\n\nSource ports added to the config: {found}"
        wx.MessageBox(message, "pyZDL Setup", wx.OK)
        self.Close()


def main():
    app = wx.App(False)
    SetupFrame().Show()
    app.MainLoop()
