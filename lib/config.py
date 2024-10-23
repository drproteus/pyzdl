import os
from pathlib import Path
from dataclasses import dataclass
from typing import Optional

PYZDL_ROOT = os.getenv("PYZDL_ROOT", str(Path.home().joinpath(".config", "pyzdl")))
CONFIG_PATH = os.getenv("PYZDL_CONFIG_PATH", os.path.join(PYZDL_ROOT, "config.json"))


@dataclass
class AppSettings:
    profile_saves: bool = False
    # Source port environment variables
    doomwaddir_override: Optional[str] = None
    doomwadpath_override: Optional[list[str]] = None

    @property
    def config_path(self):
        return CONFIG_PATH

    @property
    def pyzdl_root(self):
        return PYZDL_ROOT

    @property
    def doomwaddir(self):
        return self.doomwaddir_override or os.getenv("DOOMWADDIR", self.pyzdl_root)

    @property
    def doomwadpath(self) -> Optional[list[str]]:
        if self.doomwadpath_override:
            return self.doomwadpath_override
        env_var = os.getenv("DOOMWADPATH")
        if env_var:
            return env_var.split(";")

    def get_env(self):
        env = {}
        if self.doomwaddir:
            env["DOOMWADDIR"] = self.doomwaddir
        if self.doomwadpath:
            env["DOOMWADPATH"] = ";".join(self.doomwadpath)
        return env

    @classmethod
    def from_json(cls, d):
        if not d:
            return cls()
        return cls(
            profile_saves=d.get("profile_saves", False),
            doomwaddir_override=d.get("vars", {}).get("doomwaddir"),
            doomwadpath_override=d.get("vars", {}).get("doomwadpath"),
        )

    def to_json(self):
        return {
            "pyzdl_root": self.pyzdl_root,
            "config_path": self.config_path,
            "profile_saves": self.profile_saves,
            "vars": {
                "doomwaddir": self.doomwaddir,
                "doomwadpath": self.doomwadpath,
            },
        }
