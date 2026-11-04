# pyZDL

A Python launcher for GZDoom and other Doom source ports. Profiles bundle a
source port, an IWAD, an ordered mod list, extra arguments, and optional
per-profile config/save directories so that total conversions do not stomp on
each other's settings.

## Features

- **Profile library** with search, cover art, and fast keyboard navigation.
- **Ordered load list** with enable/disable toggles and drag-and-drop file
  adding. `.deh`/`.bex` patches are passed with `-deh` automatically.
- **Per-profile isolation** for GZDoom config and save directories, with
  custom paths and sensible global defaults.
- **Live command preview** so you can see exactly what will be executed.
- **Non-blocking launches**: the GUI keeps responding while the game runs, and
  output is written to `profiles/<name>/launch.log`.
- **Preferences** for `DOOMWADDIR`, `DOOMWADPATH`, source ports, IWADs, and the
  default GZDoom config.
- **ZDL compatibility**: import/launch `.zdl` files and export profiles.
- **Atomic config writes** and clear validation errors.
- CLI with the same profiles as the GUI.

## Install

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

On macOS, install `wxPython` from a wheel (or build it) before running the GUI.

## Run

```sh
# GUI
python cli.py gui

# or directly
python gui.py

# CLI
python cli.py profiles ls
python cli.py run profile "Brutal Doom"
python cli.py config validate
python cli.py --help
```

`run.sh` starts the GUI as well.

## Configuration

By default the config lives at `~/.config/pyzdl/config.json` (or
`$PYZDL_ROOT/config.json`). Override it with `--config /path/to/config.json` or
`PYZDL_CONFIG_PATH`.

Profiles are stored under `profiles/<name>/` next to the config file:

```
~/.config/pyzdl/
  config.json
  defaults/gzdoom.ini      # optional seed config
  profiles/
    Brutal Doom/
      gzdoom.ini           # isolated config
      saves/               # isolated saves
      launch.log
      cover.jpg            # optional cover art
```

Per-profile "Use global default", "Isolated", and "Shared" controls let you
override the global config/save isolation defaults. Renaming a profile keeps
its existing folder, so isolated configs, saves, and cover art are not lost.

The JSON config is versioned and accepts both the old list form and a
name-keyed mapping:

```json
{
  "version": 2,
  "source_ports": [
    {"name": "GZDoom", "executable": "/Applications/GZDoom.app"}
  ],
  "iwads": [
    {"name": "Doom", "file": "~/Games/Doom/DOOM.WAD"}
  ],
  "profiles": [
    {
      "name": "Brutal Doom",
      "port": "GZDoom",
      "iwad": "Doom",
      "files": ["~/Games/Doom/brutal.pk3"],
      "args": "-skill 4",
      "isolate_config": true,
      "isolate_saves": true
    }
  ],
  "settings": {
    "profile_configs": true,
    "profile_saves": true,
    "vars": {"doomwaddir": "~/Games/Doom"}
  }
}
```

Paths support `~` and environment variables. Relative paths are resolved
against the config directory.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `Ctrl/Cmd+N` | New profile |
| `Ctrl/Cmd+O` | Open a ZDL file |
| `Ctrl/Cmd+S` | Save |
| `Ctrl/Cmd+L` | Launch selected profile |
| `Ctrl/Cmd+,` | Preferences |
| `F5` | Reload from disk |
| `Delete` | Delete selected profile |
| `Enter` | Launch (in the profile list) |

## Development

```sh
pip install -r requirements-dev.txt
make test
make lint
make format
```

The launcher core in `lib/launcher.py` is deliberately UI-independent and
unit-tested. The wx UI lives in `wxui/`; `gui.py` is only the entry point.

Build the macOS app bundle with:

```sh
make macos
```
