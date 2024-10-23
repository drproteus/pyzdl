import json
import click
import os
from pathlib import Path
from lib.config import PYZDL_ROOT, CONFIG_PATH


def init_default_config() -> dict:
    return {
        "source_ports": {},
        "iwads": {},
        "profiles": {},
        "settings": {"profile_saves": True, "vars": {}},
    }


def setup(config_path):
    from lib.models import LoaderApp

    if not os.path.exists(CONFIG_PATH):
        return LoaderApp.from_json(init_default_config())

    if is_json(config_path):
        with open(config_path, "r") as f:
            data_json = json.load(f)
        return LoaderApp.from_json(data_json)
    elif is_zdl(config_path):
        return LoaderApp.from_zdl_ini(path=config_path)
    else:
        raise ValueError(f"Unknown config format: {config_path}")


def write_config(app, config_path):
    os.makedirs(PYZDL_ROOT, exist_ok=True)
    with open(config_path, "w") as f:
        json.dump(app.to_json(), f, indent=2)


def default_options(fn):
    @click.option(
        "--config",
        "config_path",
        default=CONFIG_PATH,
        type=click.Path(exists=False),
    )
    def wrapped(config_path, *args, **kwargs):
        app = setup(config_path)
        return fn(app, config_path, *args, **kwargs)

    return wrapped


def default_gui_options(fn):
    @click.option(
        "--config",
        "config_path",
        default=CONFIG_PATH,
        type=click.Path(exists=False),
    )
    @click.option("--verbose", "-v", is_flag=True, default=False)
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
