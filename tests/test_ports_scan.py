import json
import os
import tempfile
import unittest

from lib import ports_scan


class FindSourcePortsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = self.tmp.name

    def _touch(self, *parts):
        path = os.path.join(self.root, *parts)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w").close()
        return path

    def test_finds_known_ports_in_program_files_and_scoop_layouts(self):
        gz = self._touch("Program Files", "GZDoom", "gzdoom.exe")
        crispy = self._touch(
            "scoop", "apps", "crispy-doom", "current", "crispy-doom.exe"
        )

        roots = [
            os.path.join(self.root, "Program Files"),
            os.path.join(self.root, "scoop", "apps"),
        ]
        found = ports_scan.find_source_ports(roots=roots)

        self.assertEqual(
            sorted(found),
            sorted(
                [
                    ports_scan.FoundPort("GZDoom", gz),
                    ports_scan.FoundPort("Crispy Doom", crispy),
                ]
            ),
        )

    def test_scoop_versioned_install_resolves_to_current(self):
        self._touch("scoop", "apps", "gzdoom", "4.14.2", "gzdoom.exe")
        current = self._touch("scoop", "apps", "gzdoom", "current", "gzdoom.exe")

        found = ports_scan.find_source_ports(
            roots=[os.path.join(self.root, "scoop", "apps")]
        )

        self.assertEqual(found, [ports_scan.FoundPort("GZDoom", current)])

    def test_ignores_unknown_executables(self):
        self._touch("Games", "notes.exe")
        self._touch("Games", "gzdoom.txt")

        self.assertEqual(ports_scan.find_source_ports(roots=[self.root]), [])

    def test_respects_depth_limit(self):
        self._touch("a", "b", "c", "d", "woof.exe")

        self.assertEqual(
            ports_scan.find_source_ports(roots=[self.root], max_depth=2), []
        )
        self.assertEqual(
            len(ports_scan.find_source_ports(roots=[self.root], max_depth=5)), 1
        )

    def test_default_roots_use_environment(self):
        env = {
            "LOCALAPPDATA": self.root,
            "PROGRAMFILES": self.root,
            "USERPROFILE": self.root,
        }
        roots = ports_scan.default_roots(env)

        self.assertEqual(roots, [self.root])


class AddPortsToConfigTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.config = os.path.join(self.tmp.name, "config.json")
        self.exe = os.path.join(self.tmp.name, "gzdoom.exe")
        open(self.exe, "w").close()

    def test_adds_new_ports_once(self):
        port = ports_scan.FoundPort("GZDoom", self.exe)

        self.assertEqual(
            ports_scan.add_ports_to_config(self.config, [port]), ["GZDoom"]
        )
        self.assertEqual(ports_scan.add_ports_to_config(self.config, [port]), [])

        with open(self.config) as handle:
            data = json.load(handle)
        self.assertEqual([p["name"] for p in data["source_ports"]], ["GZDoom"])


if __name__ == "__main__":
    unittest.main()
