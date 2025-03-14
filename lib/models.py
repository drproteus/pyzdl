import os
import sys
import subprocess
import configparser
import re
import json
import base64
import shutil
from dataclasses import dataclass, field
from typing import Optional, Union
from lib.util import is_zdl, is_json, is_app, expand_args
from lib.config import PYZDL_ROOT, AppSettings


class LoaderError(Exception):
    pass


@dataclass
class Resource:
    path: str

    @property
    def name(self) -> str:
        return os.path.basename(self.path)

    def exists(self) -> bool:
        return os.path.exists(self.path)

    def is_file(self) -> bool:
        return os.path.isfile(self.path)

    def is_directory(self) -> bool:
        return os.path.isdir(self.path)

    @property
    def cwd(self) -> str:
        return os.path.dirname(self.path)

    @classmethod
    def from_json(cls, d: Optional[Union[str, dict]]) -> Optional["Resource"]:
        if d is None:
            return None
        if isinstance(d, dict):
            # Backwards compatibility
            return cls(path=d["path"])
        return cls(path=d)

    def to_json(self) -> str:
        return self.path

    @property
    def base64(self) -> Optional[str]:
        if not self.exists():
            return
        with open(self.path, "rb") as f:
            return base64.b64encode(f.read()).decode("utf-8")

    def open(self):
        if sys.platform == "darwin":
            subprocess.call(["open", self.path])
        elif sys.platform == "win32":
            subprocess.call(["explorer", self.path])
        elif sys.platform == "linux":
            subprocess.call(["xdg-open", self.path])


@dataclass
class SourcePort:
    name: str
    executable: Resource

    def is_valid(self) -> bool:
        return self.executable.exists()

    def launch(self, args: Optional[list[str]] = None, env: Optional[dict] = None):
        args = args or []
        env = env or {}
        cmd = [self.executable.path]
        if sys.platform == "darwin" and is_app(self.executable.path):
            cmd = ["open"] + cmd
            if args:
                # append --args so the rest of args passed go to executable and not open
                cmd += ["--args"]
        if sys.platform == "win32":
            env.update(os.environ.copy())
        if sys.platform == "linux":
            env.update(os.environ.copy())
        cmd += expand_args(args)
        subprocess.call(cmd, env=env, cwd=self.executable.cwd)

    @classmethod
    def from_json(cls, d: dict) -> "SourcePort":
        return cls(
            name=d["name"],
            executable=Resource.from_json(d["executable"]),
        )

    def to_json(self) -> dict:
        return {
            "name": self.name,
            "executable": self.executable.to_json(),
        }


@dataclass
class Iwad:
    name: str
    file: Resource

    @property
    def path(self) -> str:
        return self.file.path

    @classmethod
    def from_json(cls, d: dict) -> "Iwad":
        return cls(
            name=d["name"],
            file=Resource.from_json(d["file"]),
        )

    def to_json(self) -> dict:
        return {
            "name": self.name,
            "file": self.file.to_json(),
        }


@dataclass
class Profile:
    name: str
    port: SourcePort
    iwad: Iwad
    files: Optional[list[Resource]] = field(default_factory=lambda: [])
    args: str = ""
    image: Optional[Resource] = None
    config: Optional[Resource] = None
    savedir: Optional[Resource] = None

    def launch(self, extra_args: Optional[list[str]] = None):
        self.port.launch(
            self.get_launch_args(extra_args=extra_args),
        )

    def get_profile_path(self) -> str:
        return os.path.join(PYZDL_ROOT, "profiles", self.name)

    def get_savedir_path(self) -> str:
        return (
            self.savedir.path
            if self.savedir
            else os.path.join(
                self.get_profile_path(),
                "saves",
            )
        )

    def get_default_config_path(self) -> str:
        return os.path.join(self.get_profile_path(), "gzdoom.ini")

    def get_default_config(self) -> Resource:
        return Resource(path=self.get_default_config_path())

    def get_cover_art(self) -> Optional[Resource]:
        filenames = ["cover.jpg", "cover.png"]
        for filename in filenames:
            image = Resource(path=os.path.join(self.get_profile_path(), filename))
            if image.exists():
                return image
        return None

    def get_args(self, extra_args: Optional[list[str]] = None):
        args = extra_args or []
        if self.args:
            args += self.args.split(" ")
        if "-config" not in args:
            args.append("-config")
            if self.config:
                args.append(self.config.path)
            else:
                args.append(self.get_default_config().path)
        return args

    def get_launch_args(self, extra_args: Optional[list[str]] = None):
        args = ["-iwad", self.iwad.path]
        for file in self.files or []:
            if not file.exists():
                raise LoaderError(f"{file.path} does not exist!")
            elif not file.is_file():
                raise LoaderError(f"{file.path} should be a file, not a directory!")
            args.append("-file")
            args.append(file.path)
        args += self.get_args(extra_args=extra_args)
        return args

    @classmethod
    def from_json(cls, d: dict) -> "Profile":
        return cls(
            name=d["name"],
            port=SourcePort.from_json(d["port"]),
            iwad=Iwad.from_json(d["iwad"]),
            files=[Resource.from_json(f) for f in d.get("files", [])],
            args=d.get("args", ""),
            image=Resource.from_json(d.get("image")),
            config=Resource.from_json(d.get("config")),
            savedir=Resource.from_json(d.get("savedir")),
        )

    def to_json(self) -> dict:
        return {
            "name": self.name,
            "port": self.port.to_json(),
            "iwad": self.iwad.to_json(),
            "files": [f.to_json() for f in self.files or []],
            "args": self.args or "",
            "image": self.image.to_json() if self.image else None,
            "config": self.config.to_json() if self.config else None,
            "savedir": self.savedir.to_json() if self.savedir else None,
        }

    def get_description(self) -> str:
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
            "extra": " ".join(self.get_args()),
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
    settings: AppSettings

    @classmethod
    def from_json(cls, d: dict) -> "LoaderApp":
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
            settings=AppSettings.from_json(d.get("settings")),
        )

    def to_json(self) -> dict:
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
            "settings": self.settings.to_json(),
        }

    def get_profile(self, name: str) -> Optional[Profile]:
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
        self.iwads[name] = Iwad(name=name, file=Resource(path=path))

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
            iwads[name] = Iwad(name=name, file=Resource(path=path))

        return cls(
            source_ports=source_ports,
            iwads=iwads,
            profiles={},
            settings=AppSettings(),
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

    @classmethod
    def get_default_gzdoom_ini(cls):
        return Resource(path=os.path.join(PYZDL_ROOT, "defaults", "gzdoom.ini"))

    def get_profile_launch_args(self, profile, extra_args=None):
        extra_args = extra_args or []
        launch_args = profile.get_launch_args(extra_args=extra_args)
        if self.settings.profile_saves and "-savedir" not in launch_args:
            launch_args += [
                "-savedir",
                profile.get_savedir_path(),
            ]
        return launch_args

    def launch_profile(self, name, extra_args=None):
        profile = self.profiles[name]
        use_default_config = not profile.config and "-config" not in profile.args
        if self.settings.profile_saves or use_default_config:
            os.makedirs(profile.get_profile_path(), exist_ok=True)
        if use_default_config and not profile.get_default_config().exists():
            default = self.get_default_gzdoom_ini()
            if default.exists():
                shutil.copy(default.path, profile.get_default_config_path())
        launch_args = self.get_profile_launch_args(profile, extra_args=extra_args)
        profile.port.launch(args=launch_args, env=self.settings.get_env())
