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

    def exists(self):
        return os.path.exists(self.path)

    def is_file(self):
        return os.path.isfile(self.path)

    def is_directory(self):
        return os.path.isdir(self.path)


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
        if args:
            cmd += ["--args"]
            cmd += args
        if sys.platform == "darwin":
            cmd = ["open"] + cmd
        elif sys.platform == "win32" or sys.platform == "linux":
            # TODO: verify this later, developing initially on macOS
            pass
        subprocess.call(cmd)


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
