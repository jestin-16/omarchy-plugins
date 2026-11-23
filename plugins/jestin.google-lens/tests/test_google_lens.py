import base64
import fcntl
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import MagicMock, patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("upload", ROOT / "libexec/google-lens-upload.py")
upload = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(upload)
PNG = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=")


class UploadTests(unittest.TestCase):
    def test_small_image_is_uploaded_without_reencoding(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "capture.png"
            path.write_bytes(PNG)
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": directory}), \
                 patch.object(upload.subprocess, "run") as convert:
                image, metrics = upload.prepare_image(path)
            self.assertEqual(image, PNG)
            self.assertEqual(metrics["upload_dimensions"], (1, 1))
            convert.assert_not_called()

    @unittest.skipUnless(shutil.which("magick"), "ImageMagick is optional")
    def test_balanced_mode_reduces_large_image_and_original_preserves_it(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "capture.png"
            subprocess.run(["magick", "-size", "3000x1800", "gradient:#223344-#aabbcc", str(path)],
                           check=True, capture_output=True)
            original = path.read_bytes()
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": directory}):
                image, metrics = upload.prepare_image(path)
                self.assertLessEqual(max(upload.image_dimensions(image)), 2560)
                self.assertLess(len(image), len(original))
                self.assertFalse(path.with_name("upload.png").exists())
                config = Path(directory) / "google-lens/settings.json"
                config.parent.mkdir()
                config.write_text('{"quality": "original"}')
                image, metrics = upload.prepare_image(path)
                self.assertEqual(image, original)
                self.assertEqual(metrics["quality"], "original")

    def test_theme_colors_reject_markup_and_css_injection(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "omarchy/current/theme/colors.toml"
            path.parent.mkdir(parents=True)
            path.write_text('accent = "#123456"\nbackground = "</style><script>bad()</script>"\n')
            with patch.dict(os.environ, {"XDG_STATE_HOME": directory}):
                page = upload.upload_page(PNG).decode()
            self.assertIn("#123456", page)
            self.assertNotIn("bad()", page)
            self.assertIn('id="preview"', page)

    @unittest.skipUnless(shutil.which("node"), "Node is needed to execute the upload JavaScript")
    def test_browser_submits_original_image_automatically(self):
        page = upload.upload_page(PNG).decode()
        script = re.search(r"<script>(.*?)</script>", page, re.S)[1]
        harness = r"""
const vm = require('node:vm');
const assert = require('node:assert/strict');
const input = JSON.parse(require('node:fs').readFileSync(0, 'utf8'));
let submitted = false;
const image = {};
const form = {
  action: 'https://lens.google.com/v3/upload?ep=cntpubb&re=df&s=4',
  submit() { submitted = true; }
};
class DataTransfer {
  constructor() { this.files = []; this.items = {add: f => this.files.push(f)}; }
}
vm.runInNewContext(input.script, {
  Uint8Array, atob, File, DataTransfer, URL, Date, console,
  navigator: {language: 'en-IN'},
  document: {getElementById: id => id === 'image' ? image : form}
});
assert.equal(submitted, true);
assert.equal(image.files[0].type, 'image/png');
assert.equal(image.files[0].name, 'screenshot.png');
assert.equal(new URL(form.action).searchParams.get('hl'), 'en-IN');
assert.ok(new URL(form.action).searchParams.get('st'));
image.files[0].arrayBuffer().then(buffer => {
  assert.equal(Buffer.from(buffer).toString('base64'), input.image);
});
"""
        subprocess.run(["node", "-e", harness], input=json.dumps({
            "script": script, "image": base64.b64encode(PNG).decode(),
        }), text=True, check=True, capture_output=True)
        self.assertIn('method="post" enctype="multipart/form-data"', page)
        self.assertIn('name="encoded_image"', page)

    def test_handoff_reuses_browser_and_only_serves_secret_route(self):
        responses = []
        state = {}

        class Connection:
            def __init__(self, route):
                self.request = io.BytesIO(f"GET {route} HTTP/1.1\r\nHost: localhost\r\n\r\n".encode())
                self.response = b""

            def makefile(self, *_args):
                return self.request

            def sendall(self, data):
                self.response += data

            def settimeout(self, _timeout):
                pass

        class Server:
            server_port = 12345
            server_name = "localhost"

            def __init__(self, address, handler):
                self.address = address
                self.handler = handler
                self.count = 0
                state["server"] = self

            def __enter__(self):
                return self

            def __exit__(self, *_args):
                state["closed"] = True

            def handle_request(self):
                self.count += 1
                route = "/favicon.ico" if self.count == 1 else state["url"].split(":12345", 1)[1]
                connection = Connection(route)
                self.handler(connection, ("127.0.0.1", 1234), self)
                responses.append(connection.response)

        def launch(args, **kwargs):
            self.assertEqual(args[0], "node")
            self.assertTrue(args[1].endswith("google-lens-window.mjs"))
            state["url"] = args[2]
            self.assertTrue(kwargs["start_new_session"])
            # Chromium exits successfully when another instance accepts a URL.
            return type("Browser", (), {"poll": lambda self: 0})()

        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "capture.png"
            image.write_bytes(PNG)
            with patch.object(upload, "HTTPServer", Server), patch.object(upload.subprocess, "Popen", launch):
                upload.handoff(image, directory, Path(directory) / "browser.log")
            metrics = json.loads((Path(directory) / "metrics.json").read_text())
            self.assertEqual(metrics["original_bytes"], len(PNG))
            self.assertIn("handoff_seconds", metrics)
            self.assertNotIn(base64.b64encode(PNG).decode(), json.dumps(metrics))
        self.assertEqual(state["server"].address, ("127.0.0.1", 0))
        self.assertIn(b"404 Not Found", responses[0])
        self.assertIn(b"200 OK", responses[1])
        self.assertIn(b"Cache-Control: no-store", responses[1])
        self.assertIn(base64.b64encode(PNG), responses[1])
        self.assertTrue(state["closed"])

    def test_empty_image_is_rejected_before_browser_launch(self):
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "empty.png"
            image.touch()
            with patch.object(upload.subprocess, "Popen") as browser:
                with self.assertRaisesRegex(ValueError, "Screenshot must"):
                    upload.handoff(image, directory, Path(directory) / "browser.log")
                browser.assert_not_called()

    def test_browser_failure_and_timeout_close_local_server(self):
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "capture.png"
            image.write_bytes(PNG)
            for exit_code, error in [(1, RuntimeError), (0, TimeoutError)]:
                with self.subTest(exit_code=exit_code):
                    server = MagicMock(server_port=12345)
                    server.__enter__.return_value = server
                    browser = MagicMock(returncode=exit_code)
                    browser.poll.return_value = exit_code
                    with patch.object(upload, "HTTPServer", return_value=server), \
                         patch.object(upload.subprocess, "Popen", return_value=browser), \
                         patch.object(upload.time, "monotonic", side_effect=[0, 1, 46]):
                        with self.assertRaises(error):
                            upload.handoff(image, directory, Path(directory) / "browser.log")
                    server.__exit__.assert_called_once()


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.root / "libexec").mkdir()
        (self.root / "libexec/google-lens-window.mjs").touch()
        shutil.copy2(ROOT / "libexec/google-lens-desktop.py", self.root / "libexec/google-lens-desktop.py")
        (self.root / "tmp").mkdir()
        shutil.copy2(ROOT / "bin/google-lens", self.bin / "google-lens")
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        XDG_CONFIG_HOME=str(self.root / "config"),
                        XDG_STATE_HOME=str(self.root / "state"), TMPDIR=str(self.root / "tmp"),
                        TEST_DIR=str(self.root))
        self.stub("omarchy-capture-region", "echo '0,0 100x100'")
        self.stub("grim", 'printf PNG > "${@: -1}"')
        self.stub("wl-copy", 'cat > "$TEST_DIR/clipboard"')
        self.stub("chromium", "exit 0")
        self.stub("hyprctl", "echo '[]'")
        self.stub("omarchy-notification-send", 'printf "%s\\n" "$@" >> "$TEST_DIR/notifications"')
        (self.root / "libexec/google-lens-upload.py").write_text(
            "import os, pathlib, sys\n"
            "pathlib.Path(os.environ['TEST_DIR'], 'uploaded').write_bytes(pathlib.Path(sys.argv[1]).read_bytes())\n")

    def stub(self, name, content):
        target = self.bin / name
        target.write_text("#!/bin/bash\n" + content + "\n")
        target.chmod(0o755)

    def run_launcher(self):
        return subprocess.run([str(self.bin / "google-lens"), "fullscreen"], env=self.env,
                              text=True, capture_output=True)

    def test_capture_reaches_upload_helper_and_temp_image_is_removed(self):
        result = self.run_launcher()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "uploaded").read_bytes(), b"PNG")
        self.assertEqual((self.root / "clipboard").read_bytes(), b"PNG")
        self.assertEqual(list((self.root / "tmp").iterdir()), [])

    def test_cancel_does_not_launch_upload(self):
        self.stub("omarchy-capture-region", "exit 1")
        self.assertEqual(self.run_launcher().returncode, 0)
        self.assertFalse((self.root / "uploaded").exists())

    def test_second_shortcut_during_upload_does_not_start_another_capture(self):
        lock_path = self.root / "state/google-lens/capture.lock"
        lock_path.parent.mkdir(parents=True)
        with lock_path.open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertEqual(self.run_launcher().returncode, 0)
            self.assertFalse((self.root / "uploaded").exists())

    def test_capture_failure_is_visible(self):
        self.stub("grim", "echo 'capture unavailable' >&2; exit 1")
        result = self.run_launcher()
        self.assertEqual(result.returncode, 1)
        self.assertIn("Could not capture", result.stderr)
        self.assertFalse((self.root / "uploaded").exists())

    def test_clipboard_failure_does_not_prevent_search(self):
        self.stub("wl-copy", "exit 1")
        self.assertEqual(self.run_launcher().returncode, 0)
        self.assertTrue((self.root / "uploaded").exists())


if __name__ == "__main__":
    unittest.main()
