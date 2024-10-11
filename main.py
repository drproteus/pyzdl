import json
import click
from lib.models import LoaderApp


def setup(config_path):
    with open(config_path, "r") as f:
        data_json = json.load(f)
    return LoaderApp.from_json(data_json)


@click.command("pyzdl")
@click.option(
    "--profile",
    "profile_name",
    type=click.STRING,
)
@click.option(
    "--config",
    "config_path",
    default="./test/data.json",
    type=click.Path(exists=True),
)
def main(profile_name, config_path):
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


if __name__ == "__main__":
    main()
