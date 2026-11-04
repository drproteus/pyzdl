import os
import tempfile
import unittest
from unittest import mock

from installer import install
from lib.ports_scan import FoundPort


def _fake_shortcut(path, exe_path):
    with open(path, "w") as handle:
        handle.write(f"shortcut to {exe_path} gui")


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.payload = os.path.join(self.tmp.name, "payload")
        self.target = os.path.join(self.tmp.name, "install")
        os.makedirs(self.payload)
        with open(os.path.join(self.payload, "pyZDL.exe"), "w") as handle:
            handle.write("exe")
        shortcut = mock.patch.object(
            install, "create_gui_shortcut", side_effect=_fake_shortcut
        )
        shortcut.start()
        self.addCleanup(shortcut.stop)

    def test_copies_exe_and_creates_shortcut_in_install_dir(self):
        result = install.install(self.target, source=self.payload)

        self.assertEqual(result.exe_path, os.path.join(self.target, "pyZDL.exe"))
        with open(result.exe_path) as handle:
            self.assertEqual(handle.read(), "exe")
        self.assertEqual(result.shortcut_path, os.path.join(self.target, "pyZDL.lnk"))
        self.assertTrue(os.path.isfile(result.shortcut_path))
        self.assertEqual(result.added_ports, [])

    def test_desktop_option_copies_the_install_shortcut(self):
        desktop = os.path.join(self.tmp.name, "Desktop")
        os.makedirs(desktop)

        with mock.patch.object(install, "desktop_dir", return_value=desktop):
            install.install(self.target, source=self.payload, desktop_shortcut=True)

        self.assertTrue(os.path.isfile(os.path.join(desktop, "pyZDL.lnk")))

    def test_scan_adds_found_ports_to_config(self):
        found = [FoundPort("GZDoom", os.path.join(self.tmp.name, "gzdoom.exe"))]
        open(found[0].path, "w").close()

        with mock.patch.object(install, "find_source_ports", return_value=found):
            result = install.install(self.target, source=self.payload, scan_ports=True)

        self.assertEqual(result.added_ports, ["GZDoom"])
        self.assertTrue(os.path.isfile(os.path.join(self.target, "config.json")))

    def test_scan_is_skipped_by_default(self):
        with mock.patch.object(install, "find_source_ports") as scan:
            install.install(self.target, source=self.payload)

        scan.assert_not_called()


if __name__ == "__main__":
    unittest.main()
