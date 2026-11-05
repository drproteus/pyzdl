"""
py2app configuration for building the pyZDL macOS app bundle.

Usage:
    python setup.py py2app
    # or, via the build script (recommended):
    scripts/build-macos.sh

The target architecture is read from the ``PY2APP_ARCH`` environment variable
(defaults to ``arm64`` for Apple Silicon). The app icon is picked up from
``assets/pyzdl-launcher.icns`` when present; ``scripts/build-macos.sh``
generates it before running py2app.
"""

import os

from setuptools import setup

ROOT = os.path.dirname(os.path.realpath(__file__))
ICON = os.path.join(ROOT, "assets", "pyzdl-launcher.icns")

APP = ["gui.py"]
DATA_FILES = ["templates", "assets"]

OPTIONS = {
    "packages": ["lib", "wxui"],
    "arch": os.environ.get("PY2APP_ARCH", "arm64"),
    "plist": {
        "CFBundleName": "pyZDL",
        "CFBundleDisplayName": "pyZDL",
        "CFBundleIdentifier": "com.pyzdl.launcher",
        "CFBundleShortVersionString": "0.1.0",
        "CFBundleVersion": "0.1.0",
        "LSMinimumSystemVersion": "11.0",
        "NSHighResolutionCapable": True,
    },
}

if os.path.exists(ICON):
    OPTIONS["iconfile"] = ICON

setup(
    app=APP,
    name="pyZDL",
    data_files=DATA_FILES,
    options={"py2app": OPTIONS},
    # py2app 0.28.9+ rejects ``install_requires``. Without this, setuptools
    # inherits it from ``[project].dependencies`` in pyproject.toml. The real
    # dependencies are already installed by ``uv sync`` and bundled via py2app's
    # import scanning, so an empty value is correct here.
    install_requires=[],
)
