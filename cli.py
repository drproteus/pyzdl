import click
import json
import os
import subprocess
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


@pyzdl.group("config")
def config():
    pass


@config.command("inspect")
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


@config.command("edit")
@click.argument("editor", required=False)
@default_options
def edit_config(app, config_path, editor):
    if not editor:
        editor = os.getenv("EDITOR")
    cmd = [editor, config_path]
    subprocess.call(cmd)


@pyzdl.group("run")
def run():
    pass


@run.command("profile", context_settings={"ignore_unknown_options": True})
@click.argument("name", required=False)
@click.argument("extra_args", nargs=-1, type=click.UNPROCESSED)
@default_options
def run_profile(app, config_path, name, extra_args):
    if not app.profiles:
        raise click.ClickException("No available profiles.")
    if not name:
        name = next(iter(app.profiles.keys()))
        click.echo(f"No profile given, assuming {name}.", err=True)
    try:
        profile = app.profiles[name]
    except KeyError:
        raise click.ClickException(f"Could not find profile {name} in config.")
    profile.port.launch(profile.name, extra_args=extra_args)


@run.command("zdl", context_settings={"ignore_unknown_options": True})
@click.argument("path")
@click.argument("extra_args", nargs=-1, type=click.UNPROCESSED)
@default_options
def run_zdl(app, config_path, path, extra_args):
    app.launch_zdl(path, extra_args=extra_args)


@profiles.command("import")
@click.argument("path")
@click.argument("name", required=False)
@default_options
def import_profile(app, config_path, path, name):
    app.import_profile(path, name)
    write_config(app, config_path)


@profiles.command("inspect")
@click.argument("name")
@click.option(
    "--format",
    "format_type",
    type=click.Choice(choices=["json", "zdl", "ini"]),
    default="json",
)
@default_options
def inspect_profile(app, config_path, name, format_type):
    fp = click.get_text_stream("stdout")
    profile = app.profiles[name]
    if format_type == "json":
        json.dump(profile.to_json(), fp, indent=2)
    elif format_type == "zdl" or format_type == "ini":
        profile.to_zdl_ini(fp)


pyzdl.add_command(main, "gui")


if __name__ == "__main__":
    pyzdl()
