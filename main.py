import click
from lib.util import setup, write_config


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
@click.argument(
    "profile_name",
    required=False,
    type=click.STRING,
)
@default_options
def run(app, config_path, profile_name):
    app = setup(config_path=config_path)
    if not app.profiles:
        raise click.ClickException("No available profiles.")
    if not profile_name:
        profile_name = next(iter(app.profiles.keys()))
        click.echo(f"No profile given, assuming {profile_name}.", err=True)
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


@pyzdl.command("add-port")
@click.argument("name", type=click.STRING)
@click.argument("path", type=click.Path(exists=True))
@default_options
def add_source_port(app, config_path, name, path):
    app.add_source_port(name, path)
    write_config(app, config_path)


@pyzdl.command("rm-port")
@click.argument("name", type=click.STRING)
@default_options
def rm_source_port(app, config_path, name):
    port = app.rm_source_port(name)
    if port:
        write_config(app, config_path)


@pyzdl.command("add-profile")
@click.argument("name", type=click.STRING)
@click.argument("port", type=click.STRING)
@click.argument("iwad", type=click.Path(exists=True))
@click.option("--file", "files", type=click.Path(exists=True), multiple=True)
@default_options
def add_profile(app, config_path, name, port, iwad, files):
    app.add_profile(name, port, iwad, files)
    write_config(app, config_path)


@pyzdl.command("rm-profile")
@click.argument("name", type=click.STRING)
@default_options
def rm_profile(app, config_path, name):
    profile = app.rm_profile(name)
    if profile:
        write_config(app, config_path)


if __name__ == "__main__":
    pyzdl()
