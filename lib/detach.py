import ctypes
import os
import subprocess
import sys

DETACHED_PROCESS = 0x00000008
DETACHED_MARKER = "PYZDL_DETACHED"


def release_console_if_detached():
    """Drop the console Windows gave us when the detached copy's bootloader spawned it."""
    if sys.platform != "win32" or not os.environ.get(DETACHED_MARKER):
        return
    ctypes.windll.kernel32.FreeConsole()


def relaunch_gui_without_console(argv):
    """Relaunch a packaged `gui` run as a detached process with no console window.

    Returns True when a detached copy was started and this process should exit.
    `--debug` keeps the console so output stays visible.
    """
    if sys.platform != "win32" or not getattr(sys, "frozen", False):
        return False
    if os.environ.get(DETACHED_MARKER) or "--debug" in argv or "gui" not in argv:
        return False
    # Drop the bootloader's variables so the copy starts as a fresh onefile run.
    env = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith(("_PYI", "_MEIPASS"))
    }
    subprocess.Popen(
        [sys.executable, *argv],
        env={**env, DETACHED_MARKER: "1"},
        creationflags=DETACHED_PROCESS,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True,
    )
    return True
