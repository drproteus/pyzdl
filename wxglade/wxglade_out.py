#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
#
# generated by wxGlade 1.0.5 on Tue Oct 15 00:18:55 2024
#

import wx

# begin wxGlade: dependencies
# end wxGlade

# begin wxGlade: extracode
# end wxGlade


class MainWindow(wx.Frame):
    def __init__(self, *args, **kwds):
        # begin wxGlade: MainWindow.__init__
        kwds["style"] = kwds.get("style", 0) | wx.DEFAULT_FRAME_STYLE
        wx.Frame.__init__(self, *args, **kwds)
        self.SetSize((674, 718))
        self.SetTitle("pyZDL")

        self.panel_1 = wx.Panel(self, wx.ID_ANY)

        sizer_1 = wx.BoxSizer(wx.VERTICAL)

        self.tabs = wx.Notebook(self.panel_1, wx.ID_ANY)
        sizer_1.Add(self.tabs, 1, wx.EXPAND, 0)

        self.profile_tab = wx.Panel(self.tabs, wx.ID_ANY)
        self.tabs.AddPage(self.profile_tab, "Profiles")

        sizer_3 = wx.GridBagSizer(0, 0)

        self.window_1 = wx.SplitterWindow(self.profile_tab, wx.ID_ANY)
        self.window_1.SetMinimumPaneSize(20)
        sizer_3.Add(self.window_1, (0, 0), (1, 1), wx.EXPAND, 0)

        self.window_1_pane_1 = wx.Panel(self.window_1, wx.ID_ANY)

        sizer_5 = wx.GridBagSizer(0, 0)

        self.profiles_list_box = wx.ListBox(
            self.window_1_pane_1, wx.ID_ANY, choices=["Brutal Doom", "Golden Souls"]
        )
        self.profiles_list_box.SetSelection(0)
        sizer_5.Add(self.profiles_list_box, (0, 0), (1, 1), wx.EXPAND, 0)

        sizer_6 = wx.GridBagSizer(0, 0)
        sizer_5.Add(sizer_6, (1, 0), (1, 1), wx.EXPAND, 0)

        self.add_profile_button = wx.Button(self.window_1_pane_1, wx.ID_ANY, "Add")
        sizer_6.Add(self.add_profile_button, (0, 0), (1, 1), 0, 0)

        self.edit_profile_button = wx.Button(self.window_1_pane_1, wx.ID_ANY, "Edit")
        sizer_6.Add(self.edit_profile_button, (0, 1), (1, 1), 0, 0)

        self.remove_profile_button = wx.Button(
            self.window_1_pane_1, wx.ID_ANY, "Remove"
        )
        sizer_6.Add(self.remove_profile_button, (0, 2), (1, 1), wx.ALIGN_RIGHT, 0)

        self.window_1_pane_2 = wx.Panel(self.window_1, wx.ID_ANY)

        sizer_7 = wx.GridBagSizer(0, 0)

        self.profile_name = wx.StaticText(
            self.window_1_pane_2, wx.ID_ANY, "Brutal Doom"
        )
        self.profile_name.SetFont(
            wx.Font(
                18,
                wx.FONTFAMILY_SWISS,
                wx.FONTSTYLE_NORMAL,
                wx.FONTWEIGHT_NORMAL,
                0,
                ".SF NS",
            )
        )
        sizer_7.Add(self.profile_name, (0, 0), (1, 1), wx.ALIGN_CENTER, 0)

        self.profile_tree_view = wx.TreeCtrl(self.window_1_pane_2, wx.ID_ANY)
        sizer_7.Add(self.profile_tree_view, (1, 0), (1, 1), wx.EXPAND, 0)

        sizer_4 = wx.GridBagSizer(0, 0)
        sizer_3.Add(sizer_4, (1, 0), (1, 1), wx.EXPAND, 0)

        self.args_box = wx.TextCtrl(self.profile_tab, wx.ID_ANY, "")
        self.args_box.SetToolTip("extra args")
        sizer_4.Add(self.args_box, (0, 0), (1, 1), wx.ALL | wx.EXPAND, 0)

        self.launch_button = wx.Button(self.profile_tab, wx.ID_ANY, "Launch")
        sizer_4.Add(self.launch_button, (0, 1), (1, 1), 0, 0)

        self.config_tab = wx.Panel(self.tabs, wx.ID_ANY)
        self.tabs.AddPage(self.config_tab, "Config")

        sizer_8 = wx.GridBagSizer(0, 0)

        self.profile_saves_checkbox = wx.CheckBox(
            self.config_tab, wx.ID_ANY, "Profile Saves"
        )
        sizer_8.Add(self.profile_saves_checkbox, (0, 0), (1, 1), wx.ALIGN_RIGHT, 0)

        self.window_2 = wx.SplitterWindow(self.config_tab, wx.ID_ANY)
        self.window_2.SetMinimumPaneSize(20)
        sizer_8.Add(self.window_2, (1, 0), (1, 1), wx.EXPAND, 0)

        self.window_2_pane_1 = wx.Panel(self.window_2, wx.ID_ANY)

        sizer_9 = wx.GridBagSizer(0, 0)

        source_ports_config_label = wx.StaticText(
            self.window_2_pane_1, wx.ID_ANY, "Source Ports"
        )
        sizer_9.Add(source_ports_config_label, (0, 0), (1, 1), wx.ALIGN_CENTER, 0)

        self.source_ports_list_box = wx.ListBox(
            self.window_2_pane_1, wx.ID_ANY, choices=["Brutal Doom", "Golden Souls"]
        )
        self.source_ports_list_box.SetSelection(0)
        sizer_9.Add(self.source_ports_list_box, (1, 0), (1, 1), wx.EXPAND, 0)

        sizer_10 = wx.GridBagSizer(0, 0)
        sizer_9.Add(sizer_10, (2, 0), (1, 1), wx.EXPAND, 0)

        self.add_source_port_button = wx.Button(self.window_2_pane_1, wx.ID_ANY, "Add")
        sizer_10.Add(self.add_source_port_button, (0, 0), (1, 1), 0, 0)

        self.edit_source_port_button = wx.Button(
            self.window_2_pane_1, wx.ID_ANY, "Edit"
        )
        sizer_10.Add(self.edit_source_port_button, (0, 1), (1, 1), 0, 0)

        self.remove_source_port_button = wx.Button(
            self.window_2_pane_1, wx.ID_ANY, "Remove"
        )
        sizer_10.Add(self.remove_source_port_button, (0, 2), (1, 1), wx.ALIGN_RIGHT, 0)

        self.window_2_pane_2 = wx.Panel(self.window_2, wx.ID_ANY)

        sizer_11 = wx.GridBagSizer(0, 0)

        label_1 = wx.StaticText(self.window_2_pane_2, wx.ID_ANY, "IWADs")
        sizer_11.Add(label_1, (0, 0), (1, 1), wx.ALIGN_CENTER, 0)

        self.iwads_list_box = wx.ListBox(
            self.window_2_pane_2, wx.ID_ANY, choices=["Brutal Doom", "Golden Souls"]
        )
        self.iwads_list_box.SetSelection(0)
        sizer_11.Add(self.iwads_list_box, (1, 0), (1, 1), wx.EXPAND, 0)

        sizer_12 = wx.GridBagSizer(0, 0)
        sizer_11.Add(sizer_12, (2, 0), (1, 1), wx.EXPAND, 0)

        self.add_iwad_button = wx.Button(self.window_2_pane_2, wx.ID_ANY, "Add")
        sizer_12.Add(self.add_iwad_button, (0, 0), (1, 1), 0, 0)

        self.edit_iwad_button = wx.Button(self.window_2_pane_2, wx.ID_ANY, "Edit")
        sizer_12.Add(self.edit_iwad_button, (0, 1), (1, 1), 0, 0)

        self.remove_iwad_button = wx.Button(self.window_2_pane_2, wx.ID_ANY, "Remove")
        sizer_12.Add(self.remove_iwad_button, (0, 2), (1, 1), wx.ALIGN_RIGHT, 0)

        sizer_12.AddGrowableRow(0)
        sizer_12.AddGrowableCol(2)

        sizer_11.AddGrowableRow(1)
        sizer_11.AddGrowableCol(0)
        self.window_2_pane_2.SetSizer(sizer_11)

        sizer_10.AddGrowableRow(0)
        sizer_10.AddGrowableCol(2)

        sizer_9.AddGrowableRow(1)
        sizer_9.AddGrowableCol(0)
        self.window_2_pane_1.SetSizer(sizer_9)

        self.window_2.SplitVertically(self.window_2_pane_1, self.window_2_pane_2)

        sizer_8.AddGrowableRow(1)
        sizer_8.AddGrowableCol(0)
        self.config_tab.SetSizer(sizer_8)

        sizer_4.AddGrowableCol(0)

        sizer_7.AddGrowableRow(1)
        sizer_7.AddGrowableCol(0)
        self.window_1_pane_2.SetSizer(sizer_7)

        sizer_6.AddGrowableRow(0)
        sizer_6.AddGrowableCol(2)

        sizer_5.AddGrowableRow(0)
        sizer_5.AddGrowableCol(0)
        self.window_1_pane_1.SetSizer(sizer_5)

        self.window_1.SplitVertically(self.window_1_pane_1, self.window_1_pane_2)

        sizer_3.AddGrowableRow(0)
        sizer_3.AddGrowableCol(0)
        self.profile_tab.SetSizer(sizer_3)

        self.panel_1.SetSizer(sizer_1)

        self.Layout()
        # end wxGlade


# end of class MainWindow


class AddProfileDialogWindow(wx.Frame):
    def __init__(self, *args, **kwds):
        # begin wxGlade: AddProfileDialogWindow.__init__
        kwds["style"] = kwds.get("style", 0) | wx.DEFAULT_FRAME_STYLE
        wx.Frame.__init__(self, *args, **kwds)
        self.SetSize((400, 352))
        self.SetTitle("Add Profile")

        grid_sizer_1 = wx.GridBagSizer(0, 0)

        add_profile_name_label = wx.StaticText(
            self, wx.ID_ANY, "Name", style=wx.ALIGN_CENTER_HORIZONTAL
        )
        add_profile_name_label.SetMinSize((56, 20))
        grid_sizer_1.Add(add_profile_name_label, (0, 0), (1, 1), 0, 0)

        self.add_profile_name = wx.TextCtrl(self, wx.ID_ANY, "")
        grid_sizer_1.Add(self.add_profile_name, (0, 1), (1, 1), wx.EXPAND, 0)

        add_iwad_label = wx.StaticText(self, wx.ID_ANY, "IWAD")
        grid_sizer_1.Add(add_iwad_label, (1, 0), (1, 1), wx.ALIGN_CENTER, 0)

        self.add_profile_iwad_choice_list = wx.Choice(
            self, wx.ID_ANY, choices=["Doom", "Doom 2"]
        )
        self.add_profile_iwad_choice_list.SetSelection(0)
        grid_sizer_1.Add(
            self.add_profile_iwad_choice_list, (1, 1), (1, 1), wx.EXPAND, 0
        )

        add_profile_source_port_label = wx.StaticText(self, wx.ID_ANY, "Port")
        grid_sizer_1.Add(
            add_profile_source_port_label, (2, 0), (1, 1), wx.ALIGN_CENTER, 0
        )

        self.add_profile_source_port_choice_list = wx.Choice(
            self, wx.ID_ANY, choices=["GZDoom"]
        )
        self.add_profile_source_port_choice_list.SetSelection(0)
        grid_sizer_1.Add(
            self.add_profile_source_port_choice_list, (2, 1), (1, 1), wx.EXPAND, 0
        )

        add_profile_files_label = wx.StaticText(self, wx.ID_ANY, "Files")
        grid_sizer_1.Add(add_profile_files_label, (3, 0), (1, 1), wx.ALIGN_CENTER, 0)

        self.add_profile_files_list_box = wx.ListBox(
            self,
            wx.ID_ANY,
            choices=["/Users/jake/test/foo.wad", "/Users/jake/test/foo2.wad"],
        )
        grid_sizer_1.Add(self.add_profile_files_list_box, (3, 1), (1, 1), wx.EXPAND, 0)

        grid_sizer_2 = wx.GridBagSizer(0, 0)
        grid_sizer_1.Add(grid_sizer_2, (4, 1), (1, 1), wx.ALIGN_RIGHT, 0)

        self.add_profile_file_move_up_button = wx.Button(self, wx.ID_ANY, "Move Up")
        grid_sizer_2.Add(self.add_profile_file_move_up_button, (0, 0), (1, 1), 0, 0)

        self.add_profile_file_move_down_button = wx.Button(self, wx.ID_ANY, "Move Down")
        grid_sizer_2.Add(self.add_profile_file_move_down_button, (0, 1), (1, 1), 0, 0)

        self.add_profile_file_button = wx.Button(self, wx.ID_ANY, "Add")
        grid_sizer_2.Add(self.add_profile_file_button, (0, 2), (1, 1), 0, 0)

        self.remove_profile_file_button = wx.Button(self, wx.ID_ANY, "Remove")
        grid_sizer_2.Add(self.remove_profile_file_button, (0, 3), (1, 1), 0, 0)

        label_4 = wx.StaticText(self, wx.ID_ANY, "Extra")
        grid_sizer_1.Add(label_4, (5, 0), (1, 1), wx.ALIGN_CENTER, 0)

        self.add_profile_args_box = wx.TextCtrl(self, wx.ID_ANY, "")
        grid_sizer_1.Add(self.add_profile_args_box, (5, 1), (1, 1), wx.EXPAND, 0)

        grid_sizer_3 = wx.GridBagSizer(0, 0)
        grid_sizer_1.Add(grid_sizer_3, (6, 1), (1, 1), wx.ALIGN_RIGHT | wx.EXPAND, 0)

        self.add_profile_cancel_button = wx.Button(self, wx.ID_ANY, "Cancel")
        grid_sizer_3.Add(
            self.add_profile_cancel_button,
            (0, 0),
            (1, 1),
            wx.ALIGN_RIGHT | wx.EXPAND,
            0,
        )

        self.confirm_add_profile_button = wx.Button(self, wx.ID_ANY, "Confirm")
        grid_sizer_3.Add(
            self.confirm_add_profile_button, (0, 1), (1, 1), wx.ALIGN_RIGHT, 0
        )

        grid_sizer_2.AddGrowableCol(0)

        grid_sizer_1.AddGrowableRow(3)
        grid_sizer_1.AddGrowableCol(1)
        self.SetSizer(grid_sizer_1)

        self.Layout()
        # end wxGlade


# end of class AddProfileDialogWindow


class AddNamedResourceDialogWindow(wx.Frame):
    def __init__(self, *args, **kwds):
        # begin wxGlade: AddNamedResourceDialogWindow.__init__
        kwds["style"] = kwds.get("style", 0) | wx.DEFAULT_FRAME_STYLE
        wx.Frame.__init__(self, *args, **kwds)
        self.SetSize((400, 120))
        self.SetTitle("Add Resource")

        grid_sizer_1 = wx.GridBagSizer(0, 0)

        add_profile_name_label = wx.StaticText(
            self, wx.ID_ANY, "Name", style=wx.ALIGN_CENTER_HORIZONTAL
        )
        add_profile_name_label.SetMinSize((56, 20))
        grid_sizer_1.Add(add_profile_name_label, (0, 0), (1, 1), 0, 0)

        self.add_named_resource_name = wx.TextCtrl(self, wx.ID_ANY, "")
        grid_sizer_1.Add(self.add_named_resource_name, (0, 1), (1, 1), wx.EXPAND, 0)

        add_named_resource_label = wx.StaticText(self, wx.ID_ANY, "Path")
        grid_sizer_1.Add(add_named_resource_label, (1, 0), (1, 1), wx.ALIGN_CENTER, 0)

        sizer_1 = wx.BoxSizer(wx.VERTICAL)
        grid_sizer_1.Add(sizer_1, (1, 1), (1, 1), wx.EXPAND, 0)

        sizer_2 = wx.GridBagSizer(0, 0)
        sizer_1.Add(sizer_2, 1, wx.EXPAND, 0)

        self.add_named_resource_file_path = wx.TextCtrl(self, wx.ID_ANY, "")
        sizer_2.Add(self.add_named_resource_file_path, (0, 0), (1, 1), wx.EXPAND, 0)

        self.add_named_resource_open_button = wx.Button(self, wx.ID_ANY, "Open")
        sizer_2.Add(self.add_named_resource_open_button, (0, 1), (1, 1), 0, 0)

        grid_sizer_2 = wx.GridBagSizer(0, 0)
        grid_sizer_1.Add(grid_sizer_2, (2, 1), (1, 1), wx.EXPAND, 0)

        self.cancel_add_named_resource_button = wx.Button(self, wx.ID_ANY, "Cancel")
        grid_sizer_2.Add(self.cancel_add_named_resource_button, (0, 0), (1, 1), 0, 0)

        self.add_named_resource_confirm_button = wx.Button(self, wx.ID_ANY, "Add")
        grid_sizer_2.Add(
            self.add_named_resource_confirm_button, (0, 1), (1, 1), wx.ALIGN_RIGHT, 0
        )

        grid_sizer_2.AddGrowableRow(0)
        grid_sizer_2.AddGrowableCol(1)

        sizer_2.AddGrowableRow(0)
        sizer_2.AddGrowableCol(0)

        grid_sizer_1.AddGrowableCol(1)
        self.SetSizer(grid_sizer_1)

        self.Layout()
        # end wxGlade


# end of class AddNamedResourceDialogWindow


class MyApp(wx.App):
    def OnInit(self):
        self.pyZDL = MainWindow(None, wx.ID_ANY, "")
        self.SetTopWindow(self.pyZDL)
        self.pyZDL.Show()
        return True


# end of class MyApp

if __name__ == "__main__":
    app = MyApp(0)
    app.MainLoop()
