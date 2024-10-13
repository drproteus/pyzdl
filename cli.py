import click
import json
from lib.util import write_config, default_options
from gui import main


@click.group("pyzdl")
def pyzdl():
    pass


@pyzdl.group("profiles")
def profiles():
    pass


@pyzdl.group("iwads")
def iwads():
    pass


@pyzdl.group("ports")
def ports():
    pass


@profiles.command("ls")
@default_options
def ls_profiles(app, config_path):
    for profile_name, profile in app.profiles.items():
        click.echo(f"{profile_name} ({profile.port.name})")


@ports.command("ls")
@default_options
def ls_ports(app, config_path):
    for source_port_name, source_port in app.source_ports.items():
        click.echo(f"{source_port_name} ({source_port.executable.path})")


@iwads.command("ls")
@default_options
def ls_iwads(app, config_path):
    for iwad_name, iwad in app.iwads.items():
        click.echo(f"{iwad_name} ({iwad.path})")


@ports.command("add")
@click.argument("name", type=click.STRING)
@click.argument("path", type=click.Path(exists=True))
@default_options
def add_source_port(app, config_path, name, path):
    app.add_source_port(name, path)
    write_config(app, config_path)


@ports.command("rm")
@click.argument("name", type=click.STRING)
@default_options
def rm_source_port(app, config_path, name):
    port = app.rm_source_port(name)
    if port:
        write_config(app, config_path)


@iwads.command("add")
@click.argument("name", type=click.STRING)
@click.argument("path", type=click.Path(exists=True))
@default_options
def add_iwad(app, config_path, name, path):
    app.add_iwad(name, path)
    write_config(app, config_path)


@iwads.command("rm")
@click.argument("name", type=click.STRING)
@default_options
def rm_iwad(app, config_path, name):
    iwad = app.rm_iwad(name)
    if iwad:
        write_config(app, config_path)


@profiles.command("add")
@click.argument("name", type=click.STRING)
@click.argument("port", type=click.STRING)
@click.argument("iwad", type=click.STRING)
@click.option("--file", "files", type=click.Path(exists=True), multiple=True)
@default_options
def add_profile(app, config_path, name, port, iwad, files):
    app.add_profile(name, port, iwad, files)
    write_config(app, config_path)


@profiles.command("rm")
@click.argument("name", type=click.STRING)
@default_options
def rm_profile(app, config_path, name):
    profile = app.rm_profile(name)
    if profile:
        write_config(app, config_path)


@profiles.command("to-zdl")
@click.argument("name", type=click.STRING)
@default_options
def zdl_profile(app, config_path, name):
    profile = app.profiles[name]
    profile.to_zdl_ini(click.get_text_stream("stdout"))


@pyzdl.group("config")
def config():
    pass


@config.command("show")
@click.option(
    "--format",
    "format_type",
    type=click.Choice(choices=["json", "zdl", "ini"]),
    default="json",
)
@default_options
def show_config(app, config_path, format_type):
    if format_type == "zdl" or format_type == "ini":
        app.to_zdl_ini(click.get_text_stream("stdout"))
    else:
        json.dump(
            app.to_json(),
            click.get_text_stream("stdout"),
            indent=2,
        )


@pyzdl.group("run")
def run():
    pass


@run.command("profile")
@click.argument("name", required=False)
@default_options
def run_profile(app, config_path, name):
    if not app.profiles:
        raise click.ClickException("No available profiles.")
    if not name:
        name = next(iter(app.profiles.keys()))
        click.echo(f"No profile given, assuming {name}.", err=True)
    try:
        profile = app.profiles[name]
    except KeyError:
        raise click.ClickException(f"Could not find profile {name} in config.")
    profile.launch()


@run.command("zdl")
@click.argument("path")
@default_options
def run_zdl(app, config_path, path):
    app.launch_zdl(path)


@profiles.command("import")
@click.argument("path")
@click.argument("name", required=False)
@default_options
def import_profile(app, config_path, path, name):
    app.import_profile(path, name)


pyzdl.add_command(main, "gui")


if __name__ == "__main__":
    pyzdl()
