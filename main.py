import json
import click
from dataclasses import dataclass
from lib.models import SourcePort, Profile


@dataclass
class LoaderApp:
    source_ports: dict[str, SourcePort]
    profiles: dict[str, Profile]


def setup():
    source_ports = {}
    with open("./test/data.json", "r") as f:
        data_json = json.load(f)
    source_ports_json = data_json["source_ports"]
    for source_port_json in source_ports_json:
        source_ports[source_port_json["name"]] = SourcePort.from_json(source_port_json)
    profiles_json = data_json["profiles"]
    profiles = {}
    for profile_json in profiles_json:
        # Update JSON with shared source_port mapping.
        profile_json["port"] = source_ports[profile_json["port"]].to_json()
        profiles[profile_json["name"]] = Profile.from_json(profile_json)
    return LoaderApp(
        source_ports=source_ports,
        profiles=profiles,
    )


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
