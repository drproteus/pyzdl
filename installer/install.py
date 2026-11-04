"""Portable install logic for pyZDL. Has no GUI dependencies so it can be tested."""

import os
import shutil
import subprocess
import sys
from collections import namedtuple

from lib.ports_scan import add_ports_to_config, find_source_ports

APP_NAME = "pyZDL"
EXE_NAME = "pyZDL.exe"
SHORTCUT_NAME = "pyZDL.lnk"
SW_SHOWMINIMIZED = 7

InstallResult = namedtuple(
    "InstallResult", ["exe_path", "shortcut_path", "added_ports"]
)


def payload_dir():
    """Folder holding pyZDL.exe, bundled into the setup executable."""
    root = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    return os.path.join(getattr(sys, "_MEIPASS", root), "payload")


def default_install_dir():
    base = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
    return os.path.join(base, "Programs", APP_NAME)


def _powershell(script, env=None):
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    return subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
        check=True,
        capture_output=True,
        text=True,
        env={**os.environ, **(env or {})},
        creationflags=flags,
    ).stdout.strip()


def desktop_dir():
    return _powershell("[Environment]::GetFolderPath('Desktop')")


def create_gui_shortcut(path, exe_path):
    """Shortcut that opens the GUI. The `gui` argument makes pyZDL skip the console."""
    script = (
        "$ws = New-Object -ComObject WScript.Shell; "
        "$link = $ws.CreateShortcut($env:PYZDL_LINK); "
        "$link.TargetPath = $env:PYZDL_TARGET; "
        "$link.Arguments = 'gui'; "
        "$link.WorkingDirectory = Split-Path -Parent $env:PYZDL_TARGET; "
        f"$link.WindowStyle = {SW_SHOWMINIMIZED}; "
        "$link.IconLocation = $env:PYZDL_TARGET; "
        "$link.Save()"
    )
    _powershell(script, {"PYZDL_LINK": path, "PYZDL_TARGET": exe_path})


def install(install_dir, source=None, desktop_shortcut=False, scan_ports=False):
    """Install pyZDL into install_dir and return an InstallResult."""
    source = source or payload_dir()
    os.makedirs(install_dir, exist_ok=True)

    exe_path = os.path.join(install_dir, EXE_NAME)
    shutil.copy2(os.path.join(source, EXE_NAME), exe_path)

    shortcut_path = os.path.join(install_dir, SHORTCUT_NAME)
    create_gui_shortcut(shortcut_path, exe_path)

    added = []
    if scan_ports:
        config_path = os.path.join(install_dir, "config.json")
        added = add_ports_to_config(config_path, find_source_ports())

    if desktop_shortcut:
        shutil.copy2(shortcut_path, os.path.join(desktop_dir(), SHORTCUT_NAME))

    return InstallResult(exe_path, shortcut_path, added)
