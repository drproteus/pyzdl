import os
import sys
import subprocess
from dataclasses import dataclass
from typing import Optional


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
        if sys.platform == "darwin":
            cmd = ["open"] + cmd
            if args:
                cmd += ["--args"]
                cmd += args
        elif sys.platform == "win32" or sys.platform == "linux":
            # TODO: verify this later, developing initially on macOS
            cmd += args
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
class Profile:
    name: str
    port: SourcePort
    iwad: Resource
    files: Optional[list[Resource]]

    def launch(self):
        args = ["-iwad", self.iwad.path]
        for file in self.files or []:
            if not file.exists():
                raise LoaderError(f"{file.path} does not exist!")
            elif not file.is_file():
                raise LoaderError(f"{file.path} should be a file, not a directory!")
            args.append("-file")
            args.append(file.path)
        self.port.launch(args)

    @classmethod
    def from_json(cls, d):
        return cls(
            name=d["name"],
            port=SourcePort.from_json(d["port"]),
            iwad=Resource.from_json(d["iwad"]),
            files=[Resource.from_json(f) for f in d.get("files", [])],
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


@dataclass
class LoaderApp:
    source_ports: dict[str, SourcePort]
    profiles: dict[str, Profile]

    @classmethod
    def from_json(cls, d):
        source_ports, profiles = {}, {}
        source_ports_json = d["source_ports"]
        for source_port_json in source_ports_json:
            source_ports[source_port_json["name"]] = SourcePort.from_json(
                source_port_json
            )
        profiles_json = d["profiles"]
        for profile_json in profiles_json:
            # Update JSON with shared source_port mapping.
            profile_json["port"] = source_ports[profile_json["port"]].to_json()
            profiles[profile_json["name"]] = Profile.from_json(profile_json)
        return LoaderApp(
            source_ports=source_ports,
            profiles=profiles,
        )

    def to_json(self):
        profiles_json = []
        for name, profile in self.profiles.items():
            profile_json = profile.to_json()
            profile_json["port"] = profile_json["port"]["name"]
            profiles_json.append(profile_json)
        return {
            "source_ports": [
                source_port.to_json() for name, source_port in self.source_ports.items()
            ],
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

    def add_profile(self, name, port_name, iwad_path, files):
        port = self.source_ports[port_name]
        profile = Profile(
            name=name,
            port=port,
            iwad=Resource(path=iwad_path),
            files=[Resource(path=file_path) for file_path in files],
        )
        self.profiles[name] = profile

    def rm_profile(self, name):
        return self.profiles.pop(name, None)
