import json
import click
from lib.models import LoaderApp


def setup(config_path):
    with open(config_path, "r") as f:
        data_json = json.load(f)
    return LoaderApp.from_json(data_json)


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


@click.group("pyzdl")
def pyzdl():
    pass


@pyzdl.command("run")
@click.option(
    "--profile",
    "profile_name",
    type=click.STRING,
)
@default_options
def run(app, config_path, profile_name):
    app = setup(config_path=config_path)
    if not app.profiles:
        raise click.ClickException("No available profiles.")
    if not profile_name:
        profile_name = next(iter(app.profiles.keys()))
    try:
        profile = app.profiles[profile_name]
    except KeyError:
        raise click.ClickException(f"Could not find profile {profile_name} in config.")
    profile.launch()


@pyzdl.command("ls-profiles")
@default_options
def ls_profiles(app, config_path):
    for profile_name, profile in app.profiles.items():
        click.echo(f"{profile_name} ({profile.port.name})")


@pyzdl.command("ls-ports")
@default_options
def ls_ports(app, config_path):
    for source_port_name, source_port in app.source_ports.items():
        click.echo(f"{source_port_name} ({source_port.executable.path})")


if __name__ == "__main__":
    pyzdl()
