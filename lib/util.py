import json
import click
import os
from pathlib import Path
from lib.models import LoaderApp


CONFIG_PATH = Path.home().joinpath(".config", "pyzdl", "config.json")


def setup(config_path):
    click.echo(f"Loading config from {config_path}", err=True)
    with open(config_path, "r") as f:
        data_json = json.load(f)
    app = LoaderApp.from_json(data_json)
    click.echo("Available profiles:")
    for name, _ in app.profiles.items():
        click.echo(f"* {name}", err=True)
    return app


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
