import os
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional

PYZDL_ROOT = os.getenv("PYZDL_ROOT", str(Path.home().joinpath(".config", "pyzdl")))
CONFIG_PATH = os.getenv("PYZDL_CONFIG_PATH", os.path.join(PYZDL_ROOT, "config.json"))


@dataclass
class AppSettings:
    profile_saves: bool = False
    savedir_path_override: Optional[str] = None

    @property
    def config_path(self):
        return CONFIG_PATH

    @property
    def pyzdl_root(self):
        return PYZDL_ROOT

    @property
    def savedir_path(self):
        return self.savedir_path_override or os.getenv(
            "PYZDL_SAVEDIR_PATH", os.path.join(self.pyzdl_root, "saves")
        )

    @classmethod
    def from_json(cls, d):
        if not d:
            return cls()
        return cls(
            profile_saves=d.get("profile_saves", False),
            savedir_path_override=d.get("savedir_path"),
        )

    def to_json(self):
        return {
            "pyzdl_root": self.pyzdl_root,
            "config_path": self.config_path,
            "profile_saves": self.profile_saves,
            "savedir_path": self.savedir_path,
        }
