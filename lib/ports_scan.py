import os
from collections import namedtuple

FoundPort = namedtuple("FoundPort", ["name", "path"])

KNOWN_PORTS = {
    "gzdoom": "GZDoom",
    "lzdoom": "LZDoom",
    "zdoom": "ZDoom",
    "qzdoom": "QZDoom",
    "uzdoom": "UZDoom",
    "chocolate-doom": "Chocolate Doom",
    "crispy-doom": "Crispy Doom",
    "dsda-doom": "DSDA-Doom",
    "woof": "Woof",
    "prboom-plus": "PrBoom-Plus",
    "eternity": "Eternity",
}


def default_roots(env=None):
    """Common Windows locations where source ports get installed."""
    env = os.environ if env is None else env
    user = env.get("USERPROFILE") or os.path.expanduser("~")
    scoop = env.get("SCOOP") or os.path.join(user, "scoop")
    scoop_global = env.get("SCOOP_GLOBAL") or os.path.join(
        env.get("ProgramData") or r"C:\ProgramData", "scoop"
    )
    candidates = [
        env.get("LOCALAPPDATA"),
        env.get("APPDATA"),
        env.get("PROGRAMFILES"),
        env.get("PROGRAMFILES(X86)"),
        env.get("PROGRAMW6432"),
        os.path.join(scoop, "apps"),
        os.path.join(scoop_global, "apps"),
    ]
    roots, seen = [], set()
    for path in candidates:
        if not path or not os.path.isdir(path):
            continue
        key = os.path.normcase(os.path.abspath(path))
        if key not in seen:
            seen.add(key)
            roots.append(path)
    return roots


def _prefer_scoop_current(path):
    """Scoop installs apps/<app>/<version>/; point at apps/<app>/current/ instead."""
    app_dir = os.path.dirname(os.path.dirname(path))
    if os.path.basename(os.path.dirname(app_dir)).lower() != "apps":
        return path
    candidate = os.path.join(app_dir, "current", os.path.basename(path))
    return candidate if os.path.isfile(candidate) else path


def find_source_ports(roots=None, max_depth=3):
    """Find known source port executables below each root, up to max_depth folders deep."""
    roots = default_roots() if roots is None else roots
    found, names, paths = [], set(), set()
    for root in roots:
        root = os.path.abspath(root)
        base_depth = root.rstrip(os.sep).count(os.sep)
        for dirpath, dirnames, filenames in os.walk(root):
            depth = dirpath.rstrip(os.sep).count(os.sep) - base_depth
            if depth >= max_depth:
                dirnames[:] = []
            for filename in filenames:
                stem, ext = os.path.splitext(filename)
                name = KNOWN_PORTS.get(stem.lower())
                if ext.lower() != ".exe" or name is None:
                    continue
                path = _prefer_scoop_current(os.path.join(dirpath, filename))
                key = os.path.normcase(path)
                if name in names or key in paths:
                    continue
                names.add(name)
                paths.add(key)
                found.append(FoundPort(name, path))
    return found


def add_ports_to_config(config_path, ports):
    """Add ports that the config does not already list. Returns the added names."""
    from lib.util import setup, write_config

    app = setup(config_path)
    added = []
    for port in ports:
        if port.name in app.source_ports:
            continue
        app.add_source_port(port.name, port.path)
        added.append(port.name)
    if added:
        write_config(app, config_path)
    return added
