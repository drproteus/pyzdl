# pyZDL (PureBasic)

A PureBasic rewrite of the pyZDL launcher for Windows, macOS, and Linux. It is
the successor to the Python version, which is kept under `lib/`, `wxui/`, and
`installer/` for reference. It reads and writes the same `config.json`, profile
folders, and `.zdl` files as the Python version.

Every platform uses a portable install: the executable lives in a folder with
`config.json` and `profiles/` beside it.

## Build

Requires PureBasic 6.x. Build on the OS you are targeting: the command-line
compiler does not cross-compile.

Windows (PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -File purebasic\build.ps1
```

macOS or Linux:

```sh
sh purebasic/build.sh
```

Both scripts run the unit tests, then write the programs to `purebasic/build/`.
Pass `-SkipTests` (PowerShell) or `--skip-tests` (sh) to skip the tests. Set
`PUREBASIC_COMPILER` (sh) or `-Compiler` (PowerShell) if `pbcompiler` is not
where the script expects.

Outputs:

- `pyZDL.exe` (Windows) or `pyZDL` (macOS and Linux): the launcher.
- `pyZDL-setup.exe` (Windows only): a setup window that embeds `pyZDL.exe`.
  Other platforms can unpack the launcher into a folder instead.

## Usage

The commands match the Python CLI:

```
pyZDL gui [--debug]
pyZDL profiles ls | launch-args NAME | add NAME PORT IWAD [--file PATH]... | rm NAME
pyZDL profiles import PATH [NAME] | inspect NAME [--format json|zdl|ini]
pyZDL ports ls | add NAME PATH | rm NAME
pyZDL iwads ls | add NAME PATH | rm NAME
pyZDL config inspect [--format json|zdl|ini] | edit [EDITOR] | validate
pyZDL run profile [NAME] [ARGS]... | run zdl PATH [ARGS]...
```

Add `--config PATH` to any command to choose the config file. On Windows, add
`.exe` to the program name.

Silent install on Windows, for scripts:

```
pyZDL-setup.exe --install "%LOCALAPPDATA%\Programs\pyZDL" [--no-scan] [--desktop] [--launch]
```

## Where data lives

The default config is `config.json` next to the executable, with `profiles/`
beside it. `PYZDL_ROOT` and `PYZDL_CONFIG_PATH` override the location, and
`--config` overrides both.

## Source layout

| File | Purpose |
| --- | --- |
| `pyzdl.pb` | Entry point. Dispatches to the CLI or the GUI. |
| `src/json.pbi` | JSON reader and writer. Keeps key order and supports name-keyed objects. |
| `src/platform.pbi` | Per-OS behaviour: command-line quoting, starting and tracking games, opening folders, and the Windows-only detached GUI. |
| `src/core.pbi` | Path expansion, file I/O, and the native path separator. |
| `src/ini.pbi` | INI reader for `.zdl` files. |
| `src/model.pbi` | Ports, IWADs, profiles, settings, and config load and save. |
| `src/launcher.pbi` | Builds the launch command and runs the game with output in `launch.log`. |
| `src/ports.pbi` | Finds installed source ports in each OS's usual locations. |
| `src/cli.pbi` | Command-line interface. |
| `src/gui.pbi` | Main window. |
| `src/dialogs.pbi` | New profile, add or edit resource, and preferences dialogs. |
| `setup/pyzdl-setup.pb` | Windows setup window and silent install mode. |
| `tests/tests.pb` | Unit tests for the model, launcher, config, ZDL, and port scanner. |

## Platform notes

- **Windows:** games start with the Win32 API, and their output goes to
  `launch.log`. `gui` relaunches detached so that no console window appears.
  Ports are searched in LOCALAPPDATA, APPDATA, Program Files, and the Scoop app
  folders. `DOOMWADPATH` uses `;`.
- **macOS:** games start through `/bin/sh` with output redirected to
  `launch.log`. A `.app` bundle starts with `open`, and game arguments follow
  `--args`. Ports are searched in `/Applications`, `~/Applications`, and
  `~/Games`. `DOOMWADPATH` uses `:`.
- **Linux:** the same shell launch as macOS. Ports are searched in `~/Games`,
  `/usr/games`, `/usr/local/games`, and `/opt`. Folders open with `xdg-open`.
  `DOOMWADPATH` uses `:`.

## Differences from the Python version

- The cover art supports PNG, JPEG, and BMP. WebP falls back to the default
  cover, because PureBasic has no built-in WebP decoder.
- The profile list does not show cover thumbnails.
- Errors are shown in message boxes. Status messages go to the status bar,
  not an info bar.
- The Delete key does not delete the selected profile. Use the Delete button
  or the Profile menu.
- Ctrl+, is not registered as a shortcut. Use Tools > Preferences.
- The splitter position is not saved between runs. The window size and
  position are saved.
- `profiles launch-args` prints the command line. The Python version printed a
  Python list.
- The installer is Windows-only, and the Python version's installers for
  other platforms are not replaced.

## Verification

- **Windows:** `build.ps1` runs 100 unit checks, which cover JSON, path
  expansion, argument splitting, both config forms, launch isolation, rename and
  folder rules, ZDL round-trips, port scanning, atomic writes, and the game
  command. All pass. Manual checks cover the CLI, a launch with `launch.log`
  output, the detached GUI, the main window and dialogs, and the silent
  installer.
- **macOS and Linux:** the POSIX code compiles, and its path and quoting logic
  passes the unit checks when run with `/` as the separator. Launching games,
  the port scan on real folders, and the GUI have not been run on those
  systems. Treat them as untested until `build.sh` has run there.
- **Not covered by automated tests:** the GUI event handlers, such as
  drag-and-drop and the load-order checkboxes. Test those by hand.
