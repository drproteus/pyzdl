import os
import sys
import unittest
from unittest import mock

from lib import config


class DefaultRootTests(unittest.TestCase):
    def setUp(self):
        patcher = mock.patch.dict(os.environ)
        patcher.start()
        self.addCleanup(patcher.stop)
        os.environ.pop("PYZDL_ROOT", None)

    def test_default_is_user_config_directory(self):
        self.assertEqual(
            config._default_root(),
            str(config.Path.home().joinpath(".config", "pyzdl")),
        )

    def test_frozen_build_uses_exe_directory(self):
        exe = os.path.join(os.path.abspath(os.sep), "Apps", "pyZDL", "pyZDL.exe")
        with mock.patch.object(sys, "frozen", True, create=True):
            with mock.patch.object(sys, "executable", exe):
                with mock.patch.object(sys, "platform", "win32"):
                    self.assertEqual(config._default_root(), os.path.dirname(exe))

    def test_frozen_macos_uses_user_config_directory(self):
        exe = os.path.join(
            os.path.abspath(os.sep),
            "Applications",
            "pyZDL.app",
            "Contents",
            "MacOS",
            "pyZDL",
        )
        with mock.patch.object(sys, "frozen", True, create=True):
            with mock.patch.object(sys, "executable", exe):
                with mock.patch.object(sys, "platform", "darwin"):
                    self.assertEqual(
                        config._default_root(),
                        str(config.Path.home().joinpath(".config", "pyzdl")),
                    )

    def test_pyzdl_root_env_overrides_frozen_default(self):
        exe = os.path.join(os.path.abspath(os.sep), "Apps", "pyZDL.exe")
        with mock.patch.dict(os.environ, {"PYZDL_ROOT": "/custom"}, clear=True):
            with mock.patch.object(sys, "frozen", True, create=True):
                with mock.patch.object(sys, "executable", exe):
                    self.assertEqual(config._default_root(), "/custom")


if __name__ == "__main__":
    unittest.main()
