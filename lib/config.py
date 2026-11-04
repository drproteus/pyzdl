import os
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional


def _default_root() -> str:
    if os.getenv("PYZDL_ROOT"):
        return os.getenv("PYZDL_ROOT")
    if getattr(sys, "frozen", False):
        # Portable build: keep config and profiles next to pyZDL.exe.
        return os.path.dirname(os.path.abspath(sys.executable))
    return str(Path.home().joinpath(".config", "pyzdl"))


# Kept for backwards compatibility.  Prefer AppSettings.pyzdl_root at runtime so
# that a config loaded with --config uses its own directory for profiles.
PYZDL_ROOT = _default_root()
CONFIG_PATH = os.getenv("PYZDL_CONFIG_PATH", os.path.join(PYZDL_ROOT, "config.json"))


def expand_path(path: Optional[str], base: Optional[str] = None) -> Optional[str]:
    """Expand ~, environment variables, and relative paths."""
    if not path:
        return path
    value = os.path.expandvars(os.path.expanduser(str(path)))
    if base and not os.path.isabs(value):
        value = os.path.join(base, value)
    return os.path.normpath(value)


def split_wadpath(value: Optional[str]) -> Optional[list[str]]:
    """Split a DOOMWADPATH value on both Windows and POSIX separators."""
    if not value:
        return None
    separator = ";" if ";" in value else os.pathsep
    return [part for part in value.split(separator) if part]


@dataclass
class AppSettings:
    profile_saves: bool = False
    profile_configs: bool = True
    # Source port environment variables
    doomwaddir_override: Optional[str] = None
    doomwadpath_override: Optional[list[str]] = None
    default_config: Optional[str] = None
    ui: dict[str, Any] = field(default_factory=dict)
    # Filled in by lib.util.setup() so that configs are relocatable.
    config_path: str = CONFIG_PATH
    pyzdl_root: str = PYZDL_ROOT

    def set_config_path(self, config_path: str) -> None:
        value = os.path.abspath(
            os.path.expanduser(os.path.expandvars(str(config_path)))
        )
        self.config_path = value
        self.pyzdl_root = os.path.dirname(value) or PYZDL_ROOT

    @property
    def doomwaddir(self) -> str:
        return (
            expand_path(
                self.doomwaddir_override,
                self.pyzdl_root,
            )
            or expand_path(os.getenv("DOOMWADDIR"), self.pyzdl_root)
            or self.pyzdl_root
        )

    @property
    def doomwadpath(self) -> Optional[list[str]]:
        if self.doomwadpath_override:
            return [expand_path(p, self.pyzdl_root) for p in self.doomwadpath_override]
        return split_wadpath(os.getenv("DOOMWADPATH"))

    @property
    def default_config_path(self) -> str:
        return expand_path(
            self.default_config or os.path.join("defaults", "gzdoom.ini"),
            self.pyzdl_root,
        )

    def get_env(self) -> dict[str, str]:
        env: dict[str, str] = {}
        if self.doomwaddir:
            env["DOOMWADDIR"] = self.doomwaddir
        if self.doomwadpath:
            separator = ";" if os.name == "nt" else os.pathsep
            env["DOOMWADPATH"] = separator.join(self.doomwadpath)
        return env

    @classmethod
    def from_json(cls, d: Optional[dict]) -> "AppSettings":
        if not d:
            return cls()
        variables = d.get("vars") or {}
        wadpath = variables.get("doomwadpath")
        if isinstance(wadpath, str):
            wadpath = split_wadpath(wadpath)
        return cls(
            profile_saves=bool(d.get("profile_saves", False)),
            profile_configs=bool(d.get("profile_configs", True)),
            doomwaddir_override=variables.get("doomwaddir"),
            doomwadpath_override=wadpath,
            default_config=d.get("default_config"),
            ui=dict(d.get("ui") or {}),
            config_path=d.get("config_path", CONFIG_PATH),
            pyzdl_root=d.get("pyzdl_root", PYZDL_ROOT),
        )

    def to_json(self) -> dict:
        return {
            "pyzdl_root": self.pyzdl_root,
            "config_path": self.config_path,
            "profile_saves": self.profile_saves,
            "profile_configs": self.profile_configs,
            "default_config": self.default_config,
            "vars": {
                "doomwaddir": self.doomwaddir,
                "doomwadpath": self.doomwadpath,
            },
            "ui": self.ui,
        }
