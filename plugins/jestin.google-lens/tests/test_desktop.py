import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("desktop", ROOT / "libexec/google-lens-desktop.py")
desktop = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(desktop)
WINDOW = {"address": "0x123abc", "class": desktop.APP_CLASS, "pinned": True,
          "workspace": {"id": 3, "name": "3"}, "at": [800, 50], "size": [600, 700]}


class DesktopTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.snapshot = self.root / "windows.json"

    def test_error_in_browser_title_is_not_a_compositor_failure(self):
        response = json.dumps([dict(WINDOW, title="Google Lens - Network error")])
        with patch.object(desktop.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout=response, stderr="")):
            self.assertEqual(desktop.lens_windows()[0]["address"], WINDOW["address"])

    def test_hide_unpins_then_moves_only_lens(self):
        unrelated = dict(WINDOW, address="0x999", **{"class": "chromium"})
        with patch.object(desktop, "hypr", return_value=json.dumps([WINDOW, unrelated])), \
             patch.object(desktop, "dispatch") as dispatch, patch.object(desktop.time, "sleep"):
            self.assertTrue(desktop.hide(self.snapshot))
        commands = [call.args[0] for call in dispatch.call_args_list]
        self.assertIn('action = "off"', commands[0])
        self.assertIn(desktop.HIDDEN_WORKSPACE, commands[1])
        self.assertEqual(len(commands), 2)
        self.assertEqual(json.loads(self.snapshot.read_text())["windows"], [WINDOW])

    def test_restore_returns_to_original_workspace_and_re_pins(self):
        desktop.save_json(self.snapshot, {"windows": [WINDOW]})
        hidden = dict(WINDOW, pinned=False, workspace={"id": -99, "name": desktop.HIDDEN_WORKSPACE})
        def hypr(command, *_args):
            return json.dumps({"clients": [hidden], "workspaces": [{"id": 3}],
                               "activeworkspace": {"id": 5}}[command])
        with patch.object(desktop, "hypr", side_effect=hypr), patch.object(desktop, "dispatch") as dispatch:
            desktop.restore(self.snapshot)
        commands = [call.args[0] for call in dispatch.call_args_list]
        self.assertIn('workspace = "3"', commands[0])
        self.assertIn('action = "on"', commands[1])
        self.assertFalse(self.snapshot.exists())

    def test_restore_falls_back_when_original_workspace_disappears(self):
        desktop.save_json(self.snapshot, {"windows": [WINDOW]})
        hidden = dict(WINDOW, pinned=False, workspace={"id": -99, "name": desktop.HIDDEN_WORKSPACE})
        def hypr(command, *_args):
            return json.dumps({"clients": [hidden], "workspaces": [{"id": 5}],
                               "activeworkspace": {"id": 5}}[command])
        with patch.object(desktop, "hypr", side_effect=hypr), patch.object(desktop, "dispatch") as dispatch:
            desktop.restore(self.snapshot)
        self.assertIn('workspace = "5"', dispatch.call_args_list[0].args[0])

    def test_partial_hide_failure_attempts_recovery(self):
        with patch.object(desktop, "lens_windows", return_value=[WINDOW]), \
             patch.object(desktop, "pin"), patch.object(desktop, "move", side_effect=RuntimeError("failed")), \
             patch.object(desktop, "restore") as restore:
            with self.assertRaises(RuntimeError):
                desktop.hide(self.snapshot)
            restore.assert_called_once_with(self.snapshot)
        self.assertTrue(self.snapshot.exists())

    def test_restore_failure_keeps_recovery_record(self):
        desktop.save_json(self.snapshot, {"windows": [WINDOW]})
        with patch.object(desktop, "lens_windows", side_effect=RuntimeError("unavailable")):
            with self.assertRaises(RuntimeError):
                desktop.restore(self.snapshot)
        self.assertTrue(self.snapshot.exists())

    def test_timeout_closes_only_recorded_hidden_windows(self):
        hidden = dict(WINDOW, workspace={"name": desktop.HIDDEN_WORKSPACE})
        record = {"hidden_at": 100, "windows": [WINDOW]}
        other = dict(WINDOW, address="0x456")
        with patch.object(desktop, "dispatch") as dispatch:
            self.assertTrue(desktop.expire_hidden(record, [hidden, other], [], 401))
        dispatch.assert_called_once()
        self.assertIn("0x123abc", dispatch.call_args.args[0])
        self.assertIn("window.close", dispatch.call_args.args[0])

    def test_timeout_never_closes_visible_window(self):
        record = {"hidden_at": 100, "windows": [WINDOW]}
        with patch.object(desktop, "dispatch") as dispatch:
            self.assertFalse(desktop.expire_hidden(record, [WINDOW], [], 1000))
            dispatch.assert_not_called()

    def test_timeout_respects_visible_special_workspace(self):
        hidden = dict(WINDOW, workspace={"name": desktop.HIDDEN_WORKSPACE})
        monitor = {"specialWorkspace": {"name": desktop.HIDDEN_WORKSPACE}}
        with patch.object(desktop, "dispatch") as dispatch:
            self.assertFalse(desktop.expire_hidden({"hidden_at": 100, "windows": [WINDOW]}, [hidden], [monitor], 1000))
            dispatch.assert_not_called()

    def test_short_dismissal_does_not_close_browser(self):
        with patch.object(desktop, "dispatch") as dispatch:
            self.assertFalse(desktop.expire_hidden({"hidden_at": 100}, [], [], 399))
            dispatch.assert_not_called()

    def test_preferences_are_saved_and_invalid_values_rejected(self):
        with patch.object(desktop, "CONFIG", self.root / "settings.json"), patch.object(desktop, "STATE", self.root):
            desktop.main(["mode", "low-memory"])
            desktop.main(["quality", "original"])
            self.assertEqual(desktop.settings(), {"mode": "low-memory", "quality": "original"})
            with self.assertRaises(ValueError):
                desktop.main(["mode", "surprise"])

    def test_addresses_are_validated_before_dispatch(self):
        with self.assertRaises(ValueError):
            desktop.address({"address": '\"); os.execute("bad")'})


if __name__ == "__main__":
    unittest.main()
