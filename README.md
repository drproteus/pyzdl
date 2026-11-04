# pyZDL

A Python launcher for GZDoom and other Doom source ports. Profiles bundle a
source port, an IWAD, an ordered mod list, extra arguments, and optional
per-profile config/save directories so that total conversions do not stomp on
each other's settings.

<img width="2424" height="1864" alt="image" src="https://github.com/user-attachments/assets/4badad61-8dce-4fea-a883-7a4fbeca7a01" />

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

This project uses [uv](https://docs.astral.sh/uv/) to manage the Python runtime
and dependencies. Install uv once, then sync the environment:

```sh
uv sync
```

`uv sync` downloads a supported Python (3.10–3.12, required by `wxPython`) if
needed and creates `.venv/` with all dependencies. You do not need to activate
it; prefix commands with `uv run` instead.

On macOS, `wxPython` 4.2.2 needs a wheel for your Python version (3.10–3.12);
uv will fail to build it from source otherwise.

## Run

```sh
# GUI
uv run python cli.py gui

# or directly
uv run python gui.py

# CLI
uv run python cli.py profiles ls
uv run python cli.py run profile "Brutal Doom"
uv run python cli.py config validate
uv run python cli.py --help
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
uv sync          # includes the dev group (black, ruff, pdoc3, py2app)
make test
make lint
make format
```

Dependencies are declared in `pyproject.toml` and pinned in `uv.lock`. To add a
dependency, use `uv add <package>` (or `uv add --dev <package>` for tooling),
and commit the updated `uv.lock`.

The launcher core in `lib/launcher.py` is deliberately UI-independent and
unit-tested. The wx UI lives in `wxui/`; `gui.py` is only the entry point.

Build the macOS app bundle with:

```sh
make macos
```
