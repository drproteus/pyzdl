import os
import sys
import subprocess
import configparser
import re
import json
from dataclasses import dataclass
from typing import Optional
from lib.util import is_zdl, is_json, is_app, expand_args


class LoaderError(Exception):
    pass


@dataclass
class Resource:
    path: str

    @property
    def name(self):
        return os.path.basename(self.path)

    def exists(self):
        return os.path.exists(self.path)

    def is_file(self):
        return os.path.isfile(self.path)

    def is_directory(self):
        return os.path.isdir(self.path)

    @classmethod
    def from_json(cls, d):
        return cls(path=d["path"])

    def to_json(self):
        return {"path": self.path}


@dataclass
class SourcePort:
    name: str
    executable: Resource
    description: Optional[str] = None

    def is_valid(self):
        # TODO: Validate executable or macOS app is GZDoom source port.
        return self.executable.exists()

    def launch(self, args=None):
        args = args or []
        cmd = [self.executable.path]
        if sys.platform == "darwin" and is_app(self.executable.path):
            cmd = ["open"] + cmd
            if args:
                # append --args so the rest of args passed go to executable and not open
                cmd += ["--args"]
        if sys.platform == "win32":
            # TODO: Windows specific behavior.
            pass
        if sys.platform == "linux":
            # TODO: Linux specific behavior.
            pass
        cmd += expand_args(args)
        subprocess.call(cmd)

    @classmethod
    def from_json(cls, d):
        return cls(
            name=d["name"],
            executable=Resource.from_json(d["executable"]),
            description=d.get("description"),
        )

    def to_json(self):
        return {
            "name": self.name,
            "executable": {
                "path": self.executable.path,
            },
            "description": self.description,
        }


@dataclass
class Iwad:
    name: str
    iwad: Resource

    @property
    def path(self):
        return self.iwad.path

    @classmethod
    def from_json(cls, d):
        return cls(
            name=d["name"],
            iwad=Resource.from_json(d["iwad"]),
        )

    def to_json(self):
        return {
            "name": self.name,
            "iwad": self.iwad.to_json(),
        }


@dataclass
class Profile:
    name: str
    port: SourcePort
    iwad: Iwad
    files: Optional[list[Resource]]
    args: Optional[str]

    def launch(self, extra_args=None):
        args = ["-iwad", self.iwad.path]
        extra_args = extra_args or []
        for file in self.files or []:
            if not file.exists():
                raise LoaderError(f"{file.path} does not exist!")
            elif not file.is_file():
                raise LoaderError(f"{file.path} should be a file, not a directory!")
            args.append("-file")
            args.append(file.path)
        args += self.args or ""
        args += extra_args
        self.port.launch(args)

    @classmethod
    def from_json(cls, d):
        return cls(
            name=d["name"],
            port=SourcePort.from_json(d["port"]),
            iwad=Iwad.from_json(d["iwad"]),
            files=[Resource.from_json(f) for f in d.get("files", [])],
            args=d.get("args", ""),
        )

    def to_json(self):
        return {
            "name": self.name,
            "port": self.port.to_json(),
            "iwad": self.iwad.to_json(),
            "files": [f.to_json() for f in self.files or []],
        }

    def get_description(self):
        desc = self.iwad.name
        if self.files:
            desc += "\n"
        for file in self.files or []:
            desc += f"\n{file.name}"
        return desc

    def to_zdl_ini(self, fp):
        config = configparser.ConfigParser()
        config["zdl.save"] = {
            "port": self.port.name,
            "iwad": self.iwad.name,
            "extra": self.args or "",
        }
        for i, file in enumerate(self.files or []):
            config["zdl.save"][f"file{i}"] = file.path
        config.write(fp)

    @classmethod
    def from_file(cls, app, path, name=None):
        if is_json(path):
            with open(path, "r") as f:
                profile_json = json.load(f)
                if name and not profile_json.get("name"):
                    profile_json["name"] = name
            profile_json["port"] = app.source_ports[profile_json["port"]]
            profile_json["iwad"] = app.iwads[profile_json["iwad"]]
            profile = cls.from_json(profile_json)
        elif is_zdl(path):
            if name is None:
                raise ValueError("name required for zdl import")
            profile = app.load_zdl(path, name=name)
        else:
            raise ValueError(f"Unknown file format: {path}")
        return profile


@dataclass
class LoaderApp:
    source_ports: dict[str, SourcePort]
    iwads: dict[str, Iwad]
    profiles: dict[str, Profile]

    @classmethod
    def from_json(cls, d):
        source_ports, iwads, profiles = {}, {}, {}
        source_ports_json = d["source_ports"]
        for source_port_json in source_ports_json:
            source_ports[source_port_json["name"]] = SourcePort.from_json(
                source_port_json
            )
        iwads_json = d["iwads"]
        for iwad_json in iwads_json:
            iwads[iwad_json["name"]] = Iwad.from_json(iwad_json)
        profiles_json = d["profiles"]
        for profile_json in profiles_json:
            # Update JSON with shared source_port mapping.
            profile_json["port"] = source_ports[profile_json["port"]].to_json()
            profile_json["iwad"] = iwads[profile_json["iwad"]].to_json()
            profiles[profile_json["name"]] = Profile.from_json(profile_json)
        return LoaderApp(
            source_ports=source_ports,
            iwads=iwads,
            profiles=profiles,
        )

    def to_json(self):
        profiles_json = []
        for name, profile in self.profiles.items():
            profile_json = profile.to_json()
            profile_json["port"] = profile_json["port"]["name"]
            profile_json["iwad"] = profile_json["iwad"]["name"]
            profiles_json.append(profile_json)
        return {
            "source_ports": [
                source_port.to_json() for name, source_port in self.source_ports.items()
            ],
            "iwads": [iwad.to_json() for name, iwad in self.iwads.items()],
            "profiles": profiles_json,
        }

    def get_profile(self, name):
        return self.profiles.get(name, None)

    def add_source_port(self, name, path, update=True):
        if not update and name in self.source_ports:
            raise LoaderError(f"{name} already exists, use update=True to overwrite.")
        if not os.path.exists(path):
            raise LoaderError(f"{path} does not exist.")
        self.source_ports[name] = SourcePort(name=name, executable=Resource(path=path))

    def rm_source_port(self, name):
        return self.source_ports.pop(name, None)

    def add_iwad(self, name, path):
        self.iwads[name] = Iwad(name=name, iwad=Resource(path=path))

    def rm_iwad(self, name):
        return self.iwads.pop(name, None)

    def add_profile(self, name, port_name, iwad_name, files, args=""):
        profile = Profile(
            name=name,
            port=self.source_ports[port_name],
            iwad=self.iwads[iwad_name],
            files=[Resource(path=file_path) for file_path in files],
            args=args,
        )
        self.profiles[name] = profile

    def rm_profile(self, name):
        return self.profiles.pop(name, None)

    def to_zdl_ini(self, fp):
        config = configparser.ConfigParser()
        config["zdl.ports"] = {}
        config["zdl.iwads"] = {}
        for i, (port_name, source_port) in enumerate(self.source_ports.items()):
            config["zdl.ports"][f"p{i}n"] = port_name
            config["zdl.ports"][f"p{i}f"] = source_port.executable.path
        for i, (iwad_name, iwad) in enumerate(self.iwads.items()):
            config["zdl.iwads"][f"i{i}n"] = iwad_name
            config["zdl.iwads"][f"i{i}f"] = iwad.path
        config.write(fp)

    @classmethod
    def from_zdl_ini(cls, string_value=None, path=None):
        config = configparser.ConfigParser()
        if string_value:
            config.read_string(string_value)
        elif path:
            config.read(path)
        else:
            raise ValueError("At least one of string_value or path required.")
        source_ports, iwads = {}, {}
        config_ports = config["zdl.ports"]
        config_iwads = config["zdl.iwads"]

        def get_config_indexes(section, prefix):
            indexes = []
            for key in section.keys():
                search = re.search(prefix + r"(\d+)n", key)
                if search:
                    indexes.append(int(search.group(1)))
            return indexes

        for i in get_config_indexes(config_ports, "p"):
            name = config_ports[f"p{i}n"]
            path = config_ports[f"p{i}f"]
            source_ports[name] = SourcePort(
                name=name,
                executable=Resource(path=path),
            )

        for i in get_config_indexes(config_iwads, "i"):
            name = config_iwads[f"i{i}n"]
            path = config_iwads[f"i{i}f"]
            iwads[name] = Iwad(name=name, iwad=Resource(path=path))

        return cls(
            source_ports=source_ports,
            iwads=iwads,
            profiles={},
        )

    def load_zdl(self, path, name=None) -> Profile:
        config = configparser.ConfigParser()
        config.read(path)
        zdl_config = config["zdl.save"]
        profile = Profile(
            name=name or path,
            port=self.source_ports[zdl_config["port"]],
            iwad=self.iwads[zdl_config["iwad"]],
            files=[],
            args=zdl_config.get("extra", ""),
        )
        for key, path in zdl_config.items():
            if re.match(r"file\d+", key):
                profile.files.append(Resource(path=path))
        return profile

    def launch_zdl(self, path, extra_args=None):
        profile = self.load_zdl(path)
        profile.launch(extra_args=extra_args)

    def import_profile(self, path, name=None):
        profile = Profile.from_file(self, path, name=name)
        self.profiles[profile.name] = profile
