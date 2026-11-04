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

The portable Windows build (`pyZDL.exe`, including the installed copy) instead
defaults to the folder containing the executable, so `config.json`, `profiles\`,
and `assets\` all stay together. `PYZDL_ROOT` and `--config` still override
this. Install into a folder you can write to, such as the default
`%LOCALAPPDATA%\Programs\pyZDL`, rather than `Program Files`.

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

Build the Windows executables with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1
```

This produces two single-file programs, both with the launcher icon from
`assets\pyzdl-launcher.ico` (drawn by `scripts\draw_launcher_icon.py`):

- `dist\pyZDL.exe`: the program, with the Python interpreter and dependencies
  bundled. `pyZDL.exe profiles ls` and the other CLI commands work from a
  terminal. `pyZDL.exe gui` starts the GUI without a console window. Add
  `--debug` to keep the console and its output (`pyZDL.exe gui --debug`).
- `dist\pyZDL-setup.exe`: a portable setup window that embeds `pyZDL.exe`. It
  asks for an install folder, then:
  - copies `pyZDL.exe` there,
  - always creates `pyZDL.lnk` in that folder. It opens the GUI (`gui` argument),
  - optionally copies that shortcut to the desktop,
  - optionally finds installed source ports (GZDoom, Chocolate Doom, and others)
    and writes them to the install's `config.json`,
  - optionally launches the GUI when it finishes.

It writes no registry entries, so deleting the folder uninstalls it.

Source port scanning checks `%LOCALAPPDATA%`, `%APPDATA%`, `Program Files`,
`Program Files (x86)`, and the Scoop `apps` folders (user and global), up to
three folders deep. For Scoop it uses the `current` link, so paths survive
updates. Ports already in the config are left alone.

Profile covers chosen with "Set cover" are copied into each profile's folder
under the config directory (`profiles\<name>\`, next to `pyZDL.exe`).

Build the Linux AppImage with:

```sh
make appimage    # or: bash scripts/build-appimage.sh
```

This produces `dist/pyZDL-x86_64.AppImage`. Make it executable and run it; with
no arguments it opens the GUI, and other arguments go to the CLI
(`./pyZDL-x86_64.AppImage profiles ls`). The script downloads `appimagetool`
on first use unless one is on `PATH` or set in `APPIMAGETOOL`.

The AppImage keeps its config in `~/.config/pyzdl`, like a source checkout, because
its own folder is a read-only mount. glibc is not bundled, so build on the
oldest Linux distribution you need to support; a build made on a newer system
may not run on older hosts.
