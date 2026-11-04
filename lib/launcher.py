"""Pure launch-command construction and process launching.

Keeping this separate from the Qt/wx UI makes the most important part of the
application easy to unit test: given a profile, what exactly do we execute?
"""

import os
import shlex
import subprocess
import sys
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Optional

from lib.config import AppSettings, expand_path
from lib.errors import LoaderError

if TYPE_CHECKING:  # pragma: no cover - typing only
    from lib.models import Profile


def split_args(value: Optional[str]) -> list[str]:
    """Split an argument string, respecting quotes and multiple spaces."""
    if not value:
        return []
    try:
        parts = shlex.split(value, posix=(os.name != "nt"))
    except ValueError as exc:
        raise LoaderError(f"Could not parse extra arguments: {exc}") from exc
    if os.name == "nt":
        # shlex in non-POSIX mode leaves surrounding quotes in place.
        parts = [
            (
                part[1:-1]
                if len(part) >= 2 and part[0] == part[-1] and part[0] in "\"'"
                else part
            )
            for part in parts
        ]
    return parts


def is_app(path: str) -> bool:
    return sys.platform == "darwin" and path.endswith(".app") and os.path.isdir(path)


def _has_flag(args: list[str], flag: str) -> bool:
    for arg in args:
        if arg == flag or arg.startswith(f"{flag}="):
            return True
    return False


def _resource_path(resource, base: Optional[str] = None) -> Optional[str]:
    if resource is None:
        return None
    return expand_path(resource.path, base)


def file_flag(path: str) -> str:
    suffix = os.path.splitext(path)[1].lower()
    return "-deh" if suffix in {".deh", ".bex"} else "-file"


@dataclass
class LaunchSpec:
    """A fully-resolved command, ready to be executed or previewed."""

    argv: list[str]
    env: dict[str, str] = field(default_factory=dict)
    cwd: Optional[str] = None
    game_args: list[str] = field(default_factory=list)
    config_path: Optional[str] = None
    savedir: Optional[str] = None
    log_path: Optional[str] = None

    @property
    def executable(self) -> Optional[str]:
        if not self.argv:
            return None
        if self.argv[0] == "open" and len(self.argv) > 1:
            return self.argv[1]
        return self.argv[0]

    def command_preview(self) -> str:
        if os.name == "nt":
            return subprocess.list2cmdline(self.argv)
        return shlex.join(self.argv)

    def run(self) -> subprocess.Popen:
        if self.config_path:
            os.makedirs(os.path.dirname(self.config_path), exist_ok=True)
        if self.savedir:
            os.makedirs(self.savedir, exist_ok=True)
        cwd = self.cwd
        if cwd and not os.path.isdir(cwd):
            cwd = None
        if self.log_path:
            os.makedirs(os.path.dirname(self.log_path), exist_ok=True)
            with open(self.log_path, "a") as log:
                return subprocess.Popen(
                    self.argv,
                    env=self.env or None,
                    cwd=cwd,
                    stdin=subprocess.DEVNULL,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                )
        return subprocess.Popen(
            self.argv,
            env=self.env or None,
            cwd=cwd,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def build_launch_spec(
    profile: "Profile",
    settings: AppSettings,
    extra_args: Optional[list[str]] = None,
) -> LaunchSpec:
    """Build the executable, arguments, environment, and directories for a profile."""
    port = profile.port
    executable = expand_path(port.executable.path, settings.pyzdl_root)
    if not executable or not os.path.exists(executable):
        raise LoaderError(f"Source port executable not found: {port.executable.path}")

    iwad_path = _resource_path(profile.iwad.file, settings.pyzdl_root)
    if not iwad_path or not os.path.isfile(iwad_path):
        raise LoaderError(f"IWAD not found: {profile.iwad.file.path}")

    game_args: list[str] = ["-iwad", iwad_path]
    for resource in profile.files or []:
        if not getattr(resource, "enabled", True):
            continue
        path = _resource_path(resource, settings.pyzdl_root)
        if not path or not os.path.exists(path):
            raise LoaderError(f"Mod file not found: {resource.path}")
        game_args.extend([file_flag(path), path])

    game_args.extend(split_args(profile.args))
    game_args.extend(extra_args or [])

    # Config isolation.  A profile can override the global default explicitly.
    isolate_config = (
        profile.isolate_config
        if profile.isolate_config is not None
        else settings.profile_configs
    )
    config_path = _resource_path(profile.config, settings.pyzdl_root)
    if config_path is None and isolate_config:
        config_path = profile.get_default_config_path()
    if _has_flag(game_args, "-config"):
        # The user supplied their own -config flag; do not seed or duplicate it.
        config_path = None
    elif config_path:
        if os.path.exists(config_path) and not os.path.isfile(config_path):
            raise LoaderError(f"Config path is not a file: {config_path}")
        game_args.extend(["-config", config_path])

    # Save isolation.  A custom save directory always wins.
    isolate_saves = (
        profile.isolate_saves
        if profile.isolate_saves is not None
        else settings.profile_saves
    )
    savedir = _resource_path(profile.savedir, settings.pyzdl_root)
    if savedir is None and isolate_saves:
        savedir = profile.get_savedir_path()
    if _has_flag(game_args, "-savedir"):
        savedir = None
    elif savedir:
        if os.path.exists(savedir) and not os.path.isdir(savedir):
            raise LoaderError(f"Save path is not a directory: {savedir}")
        game_args.extend(["-savedir", savedir])

    workdir = (
        _resource_path(profile.workdir, settings.pyzdl_root)
        if profile.workdir
        else None
    )
    cwd = workdir or (
        os.path.dirname(executable) if os.path.isfile(executable) else None
    )

    argv = [executable]
    if is_app(executable):
        argv = ["open", executable]
        if game_args:
            argv.append("--args")
    argv.extend(game_args)

    env = os.environ.copy()
    env.update(settings.get_env())

    return LaunchSpec(
        argv=argv,
        env=env,
        cwd=cwd,
        game_args=game_args,
        config_path=config_path,
        savedir=savedir,
        log_path=os.path.join(profile.get_profile_path(), "launch.log"),
    )
