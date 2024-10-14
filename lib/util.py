import json
import click
from pathlib import Path


CONFIG_PATH = Path.home().joinpath(".config", "pyzdl", "config.json")


def setup(config_path):
    from lib.models import LoaderApp

    if is_json(config_path):
        with open(config_path, "r") as f:
            data_json = json.load(f)
        return LoaderApp.from_json(data_json)
    elif is_zdl(config_path):
        return LoaderApp.from_zdl_ini(path=config_path)
    else:
        raise ValueError(f"Unknown config format: {config_path}")


def write_config(app, config_path):
    with open(config_path, "w") as f:
        json.dump(app.to_json(), f, indent=2)


def default_options(fn):
    @click.option(
        "--config",
        "config_path",
        default=CONFIG_PATH,
        type=click.Path(exists=True),
    )
    def wrapped(config_path, *args, **kwargs):
        app = setup(config_path)
        return fn(app, config_path, *args, **kwargs)

    return wrapped


def is_json(path):
    if Path(path).suffix == ".json":
        return True
    return False


def is_zdl(path):
    suffix = Path(path).suffix
    if suffix == ".zdl" or suffix == ".ini":
        return True
    return False


def is_app(path):
    """Check if path is valid macOS application with contents."""
    p = Path(path)
    if p.suffix == ".app" and p.is_dir():
        return True
    return False


def expand_args(args):
    return [
        str(Path(arg).expanduser()) if arg.startswith("~")
        else arg for arg in args
    ]
