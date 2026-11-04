import json
import os
import sys
import tempfile
import unittest

from lib.config import AppSettings
from lib.errors import LoaderError
from lib.launcher import build_launch_spec, split_args
from lib.models import LoaderApp, Resource
from lib.util import setup, write_config


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = self.temp.name
        self.iwad = os.path.join(self.root, "DOOM.WAD")
        self.mod = os.path.join(self.root, "mod.pk3")
        self.deh = os.path.join(self.root, "patch.deh")
        for path in (self.iwad, self.mod, self.deh):
            with open(path, "w") as handle:
                handle.write("test")
        self.config = os.path.join(self.root, "config.json")
        self.data = {
            "version": 2,
            "source_ports": [{"name": "Echo", "executable": sys.executable}],
            "iwads": [{"name": "Doom", "file": self.iwad}],
            "profiles": [
                {
                    "name": "Test",
                    "port": "Echo",
                    "iwad": "Doom",
                    "files": [self.mod, {"path": self.deh}],
                    "args": '-name "my name"',
                }
            ],
            "settings": {
                "profile_saves": True,
                "profile_configs": True,
                "vars": {"doomwaddir": self.root},
            },
        }
        with open(self.config, "w") as handle:
            json.dump(self.data, handle)
        self.app = setup(self.config)
        self.profile = self.app.profiles["Test"]

    def tearDown(self):
        self.temp.cleanup()

    def test_split_args_preserves_quotes(self):
        self.assertEqual(
            split_args('-name "my name" -skill 4'), ["-name", "my name", "-skill", "4"]
        )

    def test_launch_spec_contains_isolation_and_files(self):
        spec = build_launch_spec(self.profile, self.app.settings)
        self.assertEqual(spec.argv[0], sys.executable)
        self.assertIn("-iwad", spec.argv)
        self.assertIn(self.iwad, spec.argv)
        self.assertIn("-file", spec.argv)
        self.assertIn(self.mod, spec.argv)
        self.assertIn("-deh", spec.argv)
        self.assertIn(self.deh, spec.argv)
        self.assertIn("-config", spec.argv)
        self.assertIn("-savedir", spec.argv)
        self.assertIn("my name", spec.argv)
        self.assertEqual(spec.env["DOOMWADDIR"], self.root)

    def test_disabled_mod_is_skipped(self):
        self.profile.files[0].enabled = False
        spec = build_launch_spec(self.profile, self.app.settings)
        self.assertNotIn(self.mod, spec.argv)

    def test_custom_config_and_saves(self):
        config = os.path.join(self.root, "custom.ini")
        saves = os.path.join(self.root, "custom-saves")
        self.profile.config = Resource(path=config)
        self.profile.savedir = Resource(path=saves)
        spec = build_launch_spec(self.profile, self.app.settings)
        self.assertIn(config, spec.argv)
        self.assertIn(saves, spec.argv)
        self.assertEqual(spec.config_path, config)
        self.assertEqual(spec.savedir, saves)

    def test_user_config_flag_is_not_duplicated(self):
        self.profile.args = "-config /tmp/other.ini"
        spec = build_launch_spec(self.profile, self.app.settings)
        self.assertEqual(spec.argv.count("-config"), 1)
        self.assertIsNone(spec.config_path)

    def test_rename_source_port_updates_profiles(self):
        self.app.rename_source_port("Echo", "Echo 2")
        self.assertNotIn("Echo", self.app.source_ports)
        self.assertEqual(self.app.profiles["Test"].port.name, "Echo 2")
        write_config(self.app, self.config)
        reloaded = setup(self.config)
        self.assertEqual(reloaded.profiles["Test"].port.name, "Echo 2")

    def test_rename_iwad_updates_profiles(self):
        self.app.rename_iwad("Doom", "Doom 2")
        self.assertEqual(self.app.profiles["Test"].iwad.name, "Doom 2")
        write_config(self.app, self.config)
        reloaded = setup(self.config)
        self.assertEqual(reloaded.profiles["Test"].iwad.name, "Doom 2")

    def test_rename_profile(self):
        old_path = self.app.profiles["Test"].get_profile_path()
        self.app.rename_profile("Test", "Renamed")
        self.assertNotIn("Test", self.app.profiles)
        profile = self.app.profiles["Renamed"]
        self.assertEqual(profile.name, "Renamed")
        self.assertEqual(profile.folder, "Test")
        self.assertEqual(profile.get_profile_path(), old_path)
        write_config(self.app, self.config)
        reloaded = setup(self.config)
        self.assertEqual(reloaded.profiles["Renamed"].folder, "Test")
        self.assertEqual(reloaded.profiles["Renamed"].get_profile_path(), old_path)

    def test_new_profile_avoids_folder_collisions(self):
        self.app.rename_profile("Test", "Renamed")
        profile = self.app.add_profile("Test", "Echo", "Doom", [])
        self.assertEqual(profile.folder, "Test 2")
        self.assertNotEqual(
            profile.get_profile_path(),
            self.app.profiles["Renamed"].get_profile_path(),
        )

    def test_unknown_port_reference_is_reported(self):
        bad = dict(self.data)
        bad["profiles"] = [dict(self.data["profiles"][0], port="Missing")]
        with self.assertRaises(LoaderError):
            LoaderApp.from_json(bad)

    def test_resource_enabled_round_trip(self):
        self.profile.files[0].enabled = False
        write_config(self.app, self.config)
        reloaded = setup(self.config)
        self.assertFalse(reloaded.profiles["Test"].files[0].enabled)
        self.assertTrue(reloaded.profiles["Test"].files[1].enabled)

    def test_zdl_export_skips_disabled_files(self):
        import configparser
        import io

        self.profile.files[0].enabled = False
        buffer = io.StringIO()
        self.profile.to_zdl_ini(buffer)
        buffer.seek(0)
        exported = configparser.ConfigParser()
        exported.read_file(buffer)
        self.assertEqual(exported["zdl.save"]["file0"], self.deh)
        self.assertNotIn("file1", exported["zdl.save"])

    def test_import_profile_with_unknown_port_is_reported(self):
        path = os.path.join(self.root, "import.json")
        with open(path, "w") as handle:
            json.dump(
                {
                    "name": "Imported",
                    "port": "Missing",
                    "iwad": "Doom",
                    "files": [],
                },
                handle,
            )
        with self.assertRaises(LoaderError):
            self.app.import_profile(path)

    def test_missing_zdl_file_is_reported(self):
        with self.assertRaises(LoaderError):
            self.app.load_zdl(os.path.join(self.root, "missing.zdl"))


class SetupTests(unittest.TestCase):
    def test_custom_config_path_controls_root(self):
        with tempfile.TemporaryDirectory() as root:
            config_path = os.path.join(root, "config.json")
            app = setup(config_path)
            self.assertEqual(app.settings.pyzdl_root, root)
            self.assertEqual(app.settings.config_path, config_path)

    def test_default_settings(self):
        settings = AppSettings()
        self.assertTrue(settings.profile_configs)
        self.assertFalse(settings.profile_saves)

    def test_invalid_json_reports_loader_error(self):
        with tempfile.TemporaryDirectory() as root:
            path = os.path.join(root, "config.json")
            with open(path, "w") as handle:
                handle.write("{not json")
            with self.assertRaises(LoaderError):
                setup(path)


if __name__ == "__main__":
    unittest.main()
