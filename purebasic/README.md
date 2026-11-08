# pyZDL (PureBasic)

A PureBasic rewrite of the pyZDL launcher for Windows. It reads and writes the
same `config.json`, profile folders, and `.zdl` files as the Python version, so
the two can share a config during the transition.

## Build

Requires PureBasic 6.x. The build script uses `pbcompiler.exe` from the
PureBasic `Compilers` folder (install default: `C:\Program Files\PureBasic`).

```powershell
powershell -ExecutionPolicy Bypass -File purebasic\build.ps1
```

This compiles the unit tests and runs them, then produces two programs in
`purebasic\build\`:

- `pyZDL.exe`: the launcher. It is a console program, so the CLI prints to a
  terminal. `pyZDL.exe gui` starts the GUI detached, with no console window.
- `pyZDL-setup.exe`: the portable setup. It embeds `pyZDL.exe`.

Use `-SkipTests` to skip the unit tests, or `-Compiler <path>` to use another
compiler.

## Usage

The commands match the Python CLI:

```
pyZDL.exe gui [--debug]
pyZDL.exe profiles ls | launch-args NAME | add NAME PORT IWAD [--file PATH]... | rm NAME
pyZDL.exe profiles import PATH [NAME] | inspect NAME [--format json|zdl|ini]
pyZDL.exe ports ls | add NAME PATH | rm NAME
pyZDL.exe iwads ls | add NAME PATH | rm NAME
pyZDL.exe config inspect [--format json|zdl|ini] | edit [EDITOR] | validate
pyZDL.exe run profile [NAME] [ARGS]... | run zdl PATH [ARGS]...
```

Add `--config PATH` to any command to choose the config file.

Silent install, for scripts:

```
pyZDL-setup.exe --install "%LOCALAPPDATA%\Programs\pyZDL" [--no-scan] [--desktop] [--launch]
```

## Where data lives

The default config is `config.json` next to `pyZDL.exe`, with `profiles\`
beside it. This matches the portable Windows build in the Python version.
`PYZDL_ROOT` and `PYZDL_CONFIG_PATH` override the location, and `--config`
overrides both.

## Source layout

| File | Purpose |
| --- | --- |
| `pyzdl.pb` | Entry point. Dispatches to the CLI or the GUI. |
| `src/json.pbi` | JSON reader and writer. Keeps key order and supports name-keyed objects. |
| `src/core.pbi` | Path expansion, file I/O, and Windows command-line quoting. |
| `src/ini.pbi` | INI reader for `.zdl` files. |
| `src/model.pbi` | Ports, IWADs, profiles, settings, and config load and save. |
| `src/launcher.pbi` | Builds the launch command and runs the game with output in `launch.log`. |
| `src/ports.pbi` | Finds installed source ports, including Scoop installs. |
| `src/cli.pbi` | Command-line interface. |
| `src/gui.pbi` | Main window. |
| `src/dialogs.pbi` | New profile, add or edit resource, and preferences dialogs. |
| `setup/pyzdl-setup.pb` | Portable setup window and silent install mode. |
| `tests/tests.pb` | Unit tests for the model, launcher, config, ZDL, and port scanner. |

The Python implementation is unchanged and still lives under `lib/`,
`wxui/`, and `installer/`.

## Differences from the Python version

- Windows only. The macOS and Linux code paths are not ported.
- Cover art supports PNG, JPEG, and BMP. WebP falls back to the default cover,
  because PureBasic has no WebP decoder built in.
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
- Drag-and-drop onto the load order list works. Dropping onto the profile
  list does nothing.

## Verification

- `build.ps1` runs 95 unit checks, which cover JSON, path expansion, argument
  splitting, both config forms, launch isolation, rename and folder rules,
  ZDL round-trips, port scanning, and atomic writes. All pass.
- Manual checks: the CLI commands, a launch with `launch.log` output, the
  detached `gui` relaunch, the main window, the Preferences and New profile
  dialogs, and the silent installer. Screenshots confirmed the layout.
- Not covered by automated tests: the GUI event handlers, such as drag-and-drop
  and load-order checkboxes. Test those by hand.
