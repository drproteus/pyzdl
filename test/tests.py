import os
import io
import unittest
import tempfile
from lib.util import setup
from lib.models import LoaderApp

TEST_DIR = os.path.dirname(os.path.realpath(__file__))


class ConfigTests(unittest.TestCase):
    @classmethod
    def get_app(cls):
        return setup(os.path.join(TEST_DIR, "data.json"))

    def test_load_config(self):
        app = self.get_app()
        self.assertTrue("GZDoom" in app.source_ports)
        self.assertTrue("Doom" in app.iwads)
        self.assertEqual(app.iwads["Doom"].file.name, "DOOM.WAD")
        self.assertEqual(len(app.profiles["Brutal Doom"].files), 2)

    def test_zdl_config(self):
        app = self.get_app()
        buffer = io.StringIO()
        app.to_zdl_ini(buffer)
        app2 = LoaderApp.from_zdl_ini(string_value=buffer.getvalue())
        self.assertDictEqual(app.source_ports, app2.source_ports)
        self.assertDictEqual(app.iwads, app2.iwads)

    def test_profile_args(self):
        app = self.get_app()
        profile = app.profiles["Brutal Doom"]
        iwad = app.iwads["Doom"]
        launch_args = " ".join(profile.get_launch_args())
        self.assertIn(f"-iwad {iwad.path}", launch_args)
        for file in profile.files:
            self.assertIn(f"-file {file.path}", launch_args)
        self.assertIn("-timedemo ./brutal.lmp", launch_args)

    def test_zdl_profile(self):
        app = self.get_app()
        profile = app.profiles["Brutal Doom"]
        with tempfile.NamedTemporaryFile("w") as t:
            profile.to_zdl_ini(t)
            t.seek(0)
            profile2 = app.load_zdl(t.name)
        self.assertEqual(
            profile.get_launch_args(),
            profile2.get_launch_args(),
        )


if __name__ == "__main__":
    unittest.main()
