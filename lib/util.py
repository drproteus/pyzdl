import json
import click
from lib.models import LoaderApp


def setup(config_path):
    with open(config_path, "r") as f:
        data_json = json.load(f)
    return LoaderApp.from_json(data_json)


def write_config(app, config_path):
    with open(config_path, "w") as f:
        json.dump(app.to_json(), f, indent=2)


def default_options(fn):
    @click.option(
        "--config",
        "config_path",
        default="./test/data.json",
        type=click.Path(exists=True),
    )
    def wrapped(config_path, *args, **kwargs):
        app = setup(config_path)
        return fn(app, config_path, *args, **kwargs)

    return wrapped
