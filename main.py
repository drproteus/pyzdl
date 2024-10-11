import json
import click
from lib.models import LoaderApp


def setup():
    with open("./test/data.json", "r") as f:
        data_json = json.load(f)
    return LoaderApp.from_json(data_json)


@click.command("pyzdl")
@click.option("--profile", "profile_name", type=click.STRING)
def main(profile_name):
    app = setup()
    if not profile_name:
        profile_name = next(iter(app.profiles.keys()))
    profile = app.profiles[profile_name]
    profile.launch()


if __name__ == "__main__":
    main()
