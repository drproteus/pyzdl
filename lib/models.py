import base64
import configparser
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from typing import Optional, Union

from lib.config import PYZDL_ROOT, AppSettings, expand_path
from lib.errors import LoaderError
from lib.launcher import build_launch_spec, file_flag, split_args
from lib.util import is_app, is_json, is_zdl


@dataclass
class Resource:
    path: str
    enabled: bool = True

    @property
    def resolved_path(self) -> str:
        return expand_path(self.path) or self.path

    @property
    def name(self) -> str:
        return os.path.basename(self.path)

    def exists(self) -> bool:
        return os.path.exists(self.resolved_path)

    def is_file(self) -> bool:
        return os.path.isfile(self.resolved_path)

    def is_directory(self) -> bool:
        return os.path.isdir(self.resolved_path)

    @property
    def cwd(self) -> str:
        return os.path.dirname(self.resolved_path)

    @classmethod
    def from_json(cls, d: Optional[Union[str, dict]]) -> Optional["Resource"]:
        if d is None:
            return None
        if isinstance(d, dict):
            # Backwards compatibility
            if "path" not in d:
                raise LoaderError("Resource is missing a path.")
            return cls(path=d["path"], enabled=d.get("enabled", True))
        return cls(path=d)

    def to_json(self):
        if self.enabled:
            return self.path
        return {"path": self.path, "enabled": False}

    @property
    def base64(self) -> Optional[str]:
        if not self.exists():
            return None
        with open(self.resolved_path, "rb") as f:
            return base64.b64encode(f.read()).decode("utf-8")

    def open(self):
        command = None
        if sys.platform == "darwin":
            command = ["open", self.resolved_path]
        elif sys.platform == "win32":
            command = ["explorer", self.resolved_path]
        elif sys.platform == "linux":
            command = ["xdg-open", self.resolved_path]
        if command:
            subprocess.Popen(command)


@dataclass
class SourcePort:
    name: str
    executable: Resource

    def is_valid(self) -> bool:
        return self.executable.exists()

    def launch(self, args: Optional[list[str]] = None, env: Optional[dict] = None):
        args = args or []
        cmd = [self.executable.resolved_path]
        if sys.platform == "darwin" and is_app(self.executable.resolved_path):
            cmd = ["open", self.executable.resolved_path]
            if args:
                # append --args so the rest of args passed go to executable and not open
                cmd += ["--args"]
        cmd += [os.path.expanduser(os.path.expandvars(arg)) for arg in args]
        process_env = os.environ.copy()
        process_env.update(env or {})
        return subprocess.Popen(cmd, env=process_env, cwd=self.executable.cwd)

    @classmethod
    def from_json(cls, d: dict) -> "SourcePort":
        executable = d.get("executable")
        if isinstance(executable, str):
            executable = {"path": executable}
        resource = Resource.from_json(executable)
        if resource is None:
            raise LoaderError("Source port is missing an executable path.")
        return cls(name=d["name"], executable=resource)

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
        file = d.get("file")
        if isinstance(file, str):
            file = {"path": file}
        resource = Resource.from_json(file)
        if resource is None:
            raise LoaderError("IWAD is missing a file path.")
        return cls(name=d["name"], file=resource)

    def to_json(self) -> dict:
        return {
            "name": self.name,
            "file": self.file.to_json(),
        }


def _safe_folder(name: str) -> str:
    return re.sub(r'[<>:"|?*]', "_", name.replace("/", "_").replace("\\", "_"))


@dataclass
class Profile:
    name: str
    port: SourcePort
    iwad: Iwad
    files: list[Resource] = field(default_factory=list)
    args: str = ""
    image: Optional[Resource] = None
    config: Optional[Resource] = None
    savedir: Optional[Resource] = None
    workdir: Optional[Resource] = None
    isolate_config: Optional[bool] = None
    isolate_saves: Optional[bool] = None
    # The on-disk folder is stable across renames.  Old configs omit it and
    # fall back to the sanitised profile name.
    folder: Optional[str] = None
    _root: Optional[str] = field(default=None, repr=False, compare=False)

    @property
    def root(self) -> str:
        return self._root or PYZDL_ROOT

    @property
    def safe_name(self) -> str:
        return _safe_folder(self.folder) if self.folder else _safe_folder(self.name)

    def launch(self, extra_args: Optional[list[str]] = None):
        """Launch without profile-isolation handling.  Prefer LoaderApp."""
        self.port.launch(self.get_launch_args(extra_args=extra_args))

    def get_profile_path(self) -> str:
        return os.path.join(self.root, "profiles", self.safe_name)

    def get_savedir_path(self) -> str:
        if self.savedir:
            return expand_path(self.savedir.path, self.root)
        return os.path.join(self.get_profile_path(), "saves")

    def get_default_config_path(self) -> str:
        return os.path.join(self.get_profile_path(), "gzdoom.ini")

    def get_default_config(self) -> Resource:
        return Resource(path=self.get_default_config_path())

    def get_cover_art(self) -> Optional[Resource]:
        for filename in ("cover.jpg", "cover.png", "cover.jpeg", "cover.webp"):
            image = Resource(path=os.path.join(self.get_profile_path(), filename))
            if image.exists():
                return image
        return None

    def get_args(self, extra_args: Optional[list[str]] = None) -> list[str]:
        """Return the user-supplied arguments (without launcher-added flags)."""
        args = split_args(self.args)
        args += extra_args or []
        return args

    def get_launch_args(self, extra_args: Optional[list[str]] = None) -> list[str]:
        """Idealised game arguments without settings-dependent isolation flags."""
        iwad_path = expand_path(self.iwad.path, self.root)
        args = ["-iwad", iwad_path]
        for file in self.files or []:
            if file.enabled:
                args.extend([file_flag(file.path), expand_path(file.path, self.root)])
        return args + self.get_args(extra_args=extra_args)

    @classmethod
    def from_json(cls, d: dict) -> "Profile":
        files = []
        for file_json in d.get("files") or []:
            resource = Resource.from_json(file_json)
            if resource is not None:
                files.append(resource)
        return cls(
            name=d["name"],
            port=SourcePort.from_json(d["port"]),
            iwad=Iwad.from_json(d["iwad"]),
            files=files,
            args=d.get("args", "") or "",
            image=Resource.from_json(d.get("image")),
            config=Resource.from_json(d.get("config")),
            savedir=Resource.from_json(d.get("savedir")),
            workdir=Resource.from_json(d.get("workdir")),
            isolate_config=d.get("isolate_config"),
            isolate_saves=d.get("isolate_saves"),
            folder=d.get("folder") or _safe_folder(d["name"]),
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
            "workdir": self.workdir.to_json() if self.workdir else None,
            "isolate_config": self.isolate_config,
            "isolate_saves": self.isolate_saves,
            "folder": self.folder,
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
            "extra": self.args or "",
        }
        for i, file in enumerate(f for f in self.files or [] if f.enabled):
            config["zdl.save"][f"file{i}"] = file.path
        config.write(fp)

    @classmethod
    def from_file(cls, app, path, name=None):
        if is_json(path):
            with open(path, "r") as f:
                profile_json = json.load(f)
                if name and not profile_json.get("name"):
                    profile_json["name"] = name
            port = profile_json["port"]
            port_name = port["name"] if isinstance(port, dict) else port
            iwad = profile_json["iwad"]
            iwad_name = iwad["name"] if isinstance(iwad, dict) else iwad
            if port_name not in app.source_ports:
                raise LoaderError(
                    f"Profile references unknown source port {port_name!r}."
                )
            if iwad_name not in app.iwads:
                raise LoaderError(f"Profile references unknown IWAD {iwad_name!r}.")
            profile_json["port"] = app.source_ports[port_name].to_json()
            profile_json["iwad"] = app.iwads[iwad_name].to_json()
            profile = cls.from_json(profile_json)
            app.attach_profile(profile)
        elif is_zdl(path):
            profile = app.load_zdl(
                path,
                name=name or os.path.splitext(os.path.basename(path))[0],
            )
        else:
            raise LoaderError(f"Unknown file format: {path}")
        return profile


def _iter_named_resources(value):
    """Accept both a list and a name->dict mapping from older configs."""
    if not value:
        return []
    if isinstance(value, dict):
        items = []
        for name, item in value.items():
            item = dict(item)
            item.setdefault("name", name)
            items.append(item)
        return items
    return list(value)


@dataclass
class LoaderApp:
    source_ports: dict[str, SourcePort]
    iwads: dict[str, Iwad]
    profiles: dict[str, Profile]
    settings: AppSettings

    @classmethod
    def from_json(cls, d: dict) -> "LoaderApp":
        source_ports, iwads, profiles = {}, {}, {}
        settings = AppSettings.from_json(d.get("settings"))

        for source_port_json in _iter_named_resources(d.get("source_ports")):
            source_port = SourcePort.from_json(source_port_json)
            if source_port.name in source_ports:
                raise LoaderError(f"Duplicate source port name: {source_port.name!r}")
            source_ports[source_port.name] = source_port

        for iwad_json in _iter_named_resources(d.get("iwads")):
            iwad = Iwad.from_json(iwad_json)
            if iwad.name in iwads:
                raise LoaderError(f"Duplicate IWAD name: {iwad.name!r}")
            iwads[iwad.name] = iwad

        for profile_json in _iter_named_resources(d.get("profiles")):
            profile_json = dict(profile_json)
            profile_name = profile_json.get("name", "<unnamed>")
            port = profile_json.get("port")
            port_name = port.get("name") if isinstance(port, dict) else port
            iwad = profile_json.get("iwad")
            iwad_name = iwad.get("name") if isinstance(iwad, dict) else iwad
            if port_name not in source_ports:
                raise LoaderError(
                    f"Profile {profile_name!r} references unknown source port {port_name!r}."
                )
            if iwad_name not in iwads:
                raise LoaderError(
                    f"Profile {profile_name!r} references unknown IWAD {iwad_name!r}."
                )
            # Update JSON with shared source_port mapping.
            profile_json["port"] = source_ports[port_name].to_json()
            profile_json["iwad"] = iwads[iwad_name].to_json()
            profile = Profile.from_json(profile_json)
            profile._root = settings.pyzdl_root
            if profile.name in profiles:
                raise LoaderError(f"Duplicate profile name: {profile.name!r}")
            profiles[profile.name] = profile

        return cls(
            source_ports=source_ports,
            iwads=iwads,
            profiles=profiles,
            settings=settings,
        )

    def to_json(self) -> dict:
        profiles_json = []
        for profile in self.profiles.values():
            profile_json = profile.to_json()
            profile_json["port"] = profile_json["port"]["name"]
            profile_json["iwad"] = profile_json["iwad"]["name"]
            profiles_json.append(profile_json)
        return {
            "version": 2,
            "source_ports": [port.to_json() for port in self.source_ports.values()],
            "iwads": [iwad.to_json() for iwad in self.iwads.values()],
            "profiles": profiles_json,
            "settings": self.settings.to_json(),
        }

    def get_profile(self, name: str) -> Optional[Profile]:
        return self.profiles.get(name, None)

    def attach_profile(self, profile: Profile) -> None:
        profile._root = self.settings.pyzdl_root

    def unique_folder(self, name: str, exclude: Optional[Profile] = None) -> str:
        """Return a sanitised folder name that no other profile is using."""
        used = {
            profile.safe_name
            for profile in self.profiles.values()
            if profile is not exclude
        }
        base = _safe_folder(name)
        candidate = base
        counter = 2
        while candidate in used:
            candidate = f"{base} {counter}"
            counter += 1
        return candidate

    def add_source_port(self, name, path, update=True):
        if not update and name in self.source_ports:
            raise LoaderError(f"{name} already exists, use update=True to overwrite.")
        if not os.path.exists(expand_path(path, self.settings.pyzdl_root)):
            raise LoaderError(f"{path} does not exist.")
        self.source_ports[name] = SourcePort(name=name, executable=Resource(path=path))

    def rm_source_port(self, name):
        profiles = self.profiles_using_port(name)
        if profiles:
            raise LoaderError(
                f"Cannot remove source port {name!r}; it is used by: {', '.join(profiles)}"
            )
        return self.source_ports.pop(name, None)

    def rename_source_port(self, old_name: str, new_name: str) -> SourcePort:
        if old_name == new_name:
            return self.source_ports[old_name]
        if new_name in self.source_ports:
            raise LoaderError(f"A source port named {new_name!r} already exists.")
        source_port = self.source_ports.pop(old_name)
        source_port.name = new_name
        self.source_ports[new_name] = source_port
        for profile in self.profiles.values():
            if profile.port is source_port or profile.port.name == old_name:
                profile.port = source_port
        return source_port

    def add_iwad(self, name, path):
        if not os.path.exists(expand_path(path, self.settings.pyzdl_root)):
            raise LoaderError(f"{path} does not exist.")
        self.iwads[name] = Iwad(name=name, file=Resource(path=path))

    def rm_iwad(self, name):
        profiles = self.profiles_using_iwad(name)
        if profiles:
            raise LoaderError(
                f"Cannot remove IWAD {name!r}; it is used by: {', '.join(profiles)}"
            )
        return self.iwads.pop(name, None)

    def rename_iwad(self, old_name: str, new_name: str) -> Iwad:
        if old_name == new_name:
            return self.iwads[old_name]
        if new_name in self.iwads:
            raise LoaderError(f"An IWAD named {new_name!r} already exists.")
        iwad = self.iwads.pop(old_name)
        iwad.name = new_name
        self.iwads[new_name] = iwad
        for profile in self.profiles.values():
            if profile.iwad is iwad or profile.iwad.name == old_name:
                profile.iwad = iwad
        return iwad

    def profiles_using_port(self, name: str) -> list[str]:
        return [p.name for p in self.profiles.values() if p.port.name == name]

    def profiles_using_iwad(self, name: str) -> list[str]:
        return [p.name for p in self.profiles.values() if p.iwad.name == name]

    def add_profile(self, name, port_name, iwad_name, files, args="", **kwargs):
        if name in self.profiles:
            raise LoaderError(f"A profile named {name!r} already exists.")
        profile = Profile(
            name=name,
            port=self.source_ports[port_name],
            iwad=self.iwads[iwad_name],
            files=[Resource(path=file_path) for file_path in files],
            args=args,
            folder=self.unique_folder(name),
            **kwargs,
        )
        self.attach_profile(profile)
        self.profiles[name] = profile
        return profile

    def rename_profile(self, old_name: str, new_name: str) -> Profile:
        if old_name == new_name:
            return self.profiles[old_name]
        if new_name in self.profiles:
            raise LoaderError(f"A profile named {new_name!r} already exists.")
        profile = self.profiles.pop(old_name)
        # Pin the existing folder so configs, saves, and cover art survive a
        # rename instead of silently switching to a new directory.
        if not profile.folder:
            profile.folder = _safe_folder(profile.name)
        profile.name = new_name
        self.profiles[new_name] = profile
        return profile

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
            if not os.path.exists(path):
                raise LoaderError(f"ZDL file not found: {path}")
            config.read(path)
        else:
            raise ValueError("At least one of string_value or path required.")
        source_ports, iwads = {}, {}
        if not config.has_section("zdl.ports") or not config.has_section("zdl.iwads"):
            raise LoaderError(
                "ZDL config must contain [zdl.ports] and [zdl.iwads] sections."
            )
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
        if not os.path.exists(path):
            raise LoaderError(f"ZDL file not found: {path}")
        config = configparser.ConfigParser()
        config.read(path)
        if not config.has_section("zdl.save"):
            raise LoaderError(f"ZDL file has no [zdl.save] section: {path}")
        zdl_config = config["zdl.save"]
        port_name = zdl_config.get("port")
        iwad_name = zdl_config.get("iwad")
        if not port_name or not iwad_name:
            raise LoaderError(f"ZDL file is missing a port or IWAD: {path}")
        if port_name not in self.source_ports:
            raise LoaderError(f"ZDL file references unknown source port {port_name!r}.")
        if iwad_name not in self.iwads:
            raise LoaderError(f"ZDL file references unknown IWAD {iwad_name!r}.")
        profile = Profile(
            name=name or os.path.splitext(os.path.basename(path))[0],
            port=self.source_ports[port_name],
            iwad=self.iwads[iwad_name],
            files=[],
            args=zdl_config.get("extra", ""),
        )
        for key, path in zdl_config.items():
            if re.match(r"file\d+", key):
                profile.files.append(Resource(path=path))
        self.attach_profile(profile)
        return profile

    def launch_zdl(self, path, extra_args=None):
        profile = self.load_zdl(path)
        return self.launch_profile(profile, extra_args=extra_args)

    def import_profile(self, path, name=None):
        profile = Profile.from_file(self, path, name=name)
        if profile.name in self.profiles:
            raise LoaderError(f"A profile named {profile.name!r} already exists.")
        used = {item.safe_name for item in self.profiles.values()}
        if not profile.folder or profile.safe_name in used:
            profile.folder = self.unique_folder(profile.name)
        self.profiles[profile.name] = profile
        return profile

    @classmethod
    def get_default_gzdoom_ini(cls, settings: Optional[AppSettings] = None):
        settings = settings or AppSettings()
        return Resource(path=settings.default_config_path)

    def get_profile_launch_args(self, profile, extra_args=None):
        spec = build_launch_spec(profile, self.settings, extra_args=extra_args)
        return spec.game_args

    def validate_profile(self, profile) -> list[str]:
        try:
            build_launch_spec(profile, self.settings)
        except LoaderError as exc:
            return [str(exc)]
        return []

    def _prepare_config(self, profile, spec) -> None:
        if not spec.config_path or os.path.exists(spec.config_path):
            return
        os.makedirs(os.path.dirname(spec.config_path), exist_ok=True)
        default = self.get_default_gzdoom_ini(self.settings)
        if default.exists():
            shutil.copyfile(default.resolved_path, spec.config_path)

    def launch_profile(self, profile_or_name, extra_args=None):
        profile = (
            profile_or_name
            if isinstance(profile_or_name, Profile)
            else self.profiles[profile_or_name]
        )
        self.attach_profile(profile)
        spec = build_launch_spec(profile, self.settings, extra_args=extra_args)
        self._prepare_config(profile, spec)
        return spec.run()
