import os
import sys
import unittest
from unittest import mock

from lib import detach


class RelaunchTests(unittest.TestCase):
    def setUp(self):
        patcher = mock.patch.dict(os.environ)
        patcher.start()
        self.addCleanup(patcher.stop)
        os.environ.pop(detach.DETACHED_MARKER, None)
        frozen = mock.patch.object(sys, "frozen", True, create=True)
        frozen.start()
        self.addCleanup(frozen.stop)
        platform = mock.patch.object(sys, "platform", "win32")
        platform.start()
        self.addCleanup(platform.stop)

    def _relaunch(self, argv):
        with mock.patch.object(detach.subprocess, "Popen") as popen:
            result = detach.relaunch_gui_without_console(argv)
        return result, popen

    def test_gui_launch_is_detached(self):
        result, popen = self._relaunch(["gui"])

        self.assertTrue(result)
        args, kwargs = popen.call_args
        self.assertEqual(args[0][1:], ["gui"])
        self.assertEqual(kwargs["creationflags"], detach.DETACHED_PROCESS)
        self.assertEqual(kwargs["env"][detach.DETACHED_MARKER], "1")

    def test_debug_keeps_console(self):
        result, popen = self._relaunch(["gui", "--debug"])

        self.assertFalse(result)
        popen.assert_not_called()

    def test_cli_commands_are_untouched(self):
        result, popen = self._relaunch(["profiles", "ls"])

        self.assertFalse(result)
        popen.assert_not_called()

    def test_already_detached_process_does_not_relaunch_again(self):
        os.environ[detach.DETACHED_MARKER] = "1"

        result, popen = self._relaunch(["gui"])

        self.assertFalse(result)
        popen.assert_not_called()

    def test_not_frozen_does_not_relaunch(self):
        with mock.patch.object(sys, "frozen", False, create=True):
            result, popen = self._relaunch(["gui"])

        self.assertFalse(result)
        popen.assert_not_called()


if __name__ == "__main__":
    unittest.main()
