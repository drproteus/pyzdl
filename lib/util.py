import json
from lib.models import LoaderApp


def setup(config_path):
    with open(config_path, "r") as f:
        data_json = json.load(f)
    return LoaderApp.from_json(data_json)


def write_config(app, config_path):
    with open(config_path, "w") as f:
        json.dump(app.to_json(), f, indent=2)
