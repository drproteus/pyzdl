import functools
import json
import os
import tempfile
from pathlib import Path

from lib.config import CONFIG_PATH
from lib.errors import LoaderError


def init_default_config() -> dict:
    return {
        "version": 2,
        "source_ports": [],
        "iwads": [],
        "profiles": [],
        "settings": {"profile_saves": True, "profile_configs": True, "vars": {}},
    }


def setup(config_path):
    from lib.models import LoaderApp

    config_path = os.path.abspath(
        os.path.expanduser(os.path.expandvars(str(config_path)))
    )
    if not os.path.exists(config_path):
        app = LoaderApp.from_json(init_default_config())
        app.settings.set_config_path(config_path)
        for profile in app.profiles.values():
            profile._root = app.settings.pyzdl_root
        return app

    if is_json(config_path):
        try:
            with open(config_path, "r") as f:
                data_json = json.load(f)
        except (OSError, json.JSONDecodeError) as exc:
            raise LoaderError(f"Could not read config {config_path}: {exc}") from exc
        if not isinstance(data_json, dict):
            raise LoaderError(f"Config must be a JSON object: {config_path}")
        app = LoaderApp.from_json(data_json)
    elif is_zdl(config_path):
        app = LoaderApp.from_zdl_ini(path=config_path)
    else:
        raise LoaderError(f"Unknown config format: {config_path}")

    app.settings.set_config_path(config_path)
    for profile in app.profiles.values():
        profile._root = app.settings.pyzdl_root
    return app


def atomic_write_text(path: str, text: str) -> None:
    """Write a file atomically so a crash cannot leave a truncated config."""
    directory = os.path.dirname(os.path.abspath(path)) or "."
    os.makedirs(directory, exist_ok=True)
    fd, temp_path = tempfile.mkstemp(prefix=".pyzdl-", suffix=".tmp", dir=directory)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        os.replace(temp_path, path)
    except BaseException:
        try:
            os.unlink(temp_path)
        except OSError:
            pass
        raise


def write_config(app, config_path):
    app.settings.set_config_path(config_path)
    for profile in app.profiles.values():
        profile._root = app.settings.pyzdl_root
    text = json.dumps(app.to_json(), indent=2)
    atomic_write_text(config_path, text + "\n")


def default_options(fn):
    import click

    @click.option(
        "--config",
        "config_path",
        default=CONFIG_PATH,
        type=click.Path(exists=False),
    )
    @functools.wraps(fn)
    def wrapped(config_path, *args, **kwargs):
        app = setup(config_path)
        return fn(app, config_path, *args, **kwargs)

    return wrapped


def default_gui_options(fn):
    import click

    @click.option(
        "--config",
        "config_path",
        default=CONFIG_PATH,
        type=click.Path(exists=False),
    )
    @click.option("--verbose", "-v", is_flag=True, default=False)
    @functools.wraps(fn)
    def wrapped(config_path, verbose, *args, **kwargs):
        return fn(config_path, verbose, *args, **kwargs)

    return wrapped


def is_json(path: str) -> bool:
    if Path(path).suffix == ".json":
        return True
    return False


def is_zdl(path: str) -> bool:
    suffix = Path(path).suffix
    if suffix == ".zdl" or suffix == ".ini":
        return True
    return False


def is_app(path: str) -> bool:
    """Check if path is valid macOS application with contents."""
    p = Path(path)
    if p.suffix == ".app" and p.is_dir():
        return True
    return False


def expand_args(args: list[str]) -> list[str]:
    return [os.path.expanduser(os.path.expandvars(arg)) for arg in args]
