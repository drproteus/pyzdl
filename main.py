import wx


def main():
    app = wx.App()
    frame = wx.Frame(None, title="pyzdl")
    panel = wx.Panel(frame)
    text = wx.StaticText(panel, label="Hello, underworld.")
    frame.Show()
    app.MainLoop()


if __name__ == "__main__":
    main()
