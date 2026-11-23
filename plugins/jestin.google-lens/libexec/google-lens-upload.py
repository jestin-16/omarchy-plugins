#!/usr/bin/env python3
"""Hand a capture to Chromium through a short-lived, loopback-only page."""

import base64
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import struct
import subprocess
import sys
import time
import tomllib


def theme_colors():
    colors = {"background": "#202124", "foreground": "#eeeeee", "accent": "#7aa2f7",
              "lighter_background": "#292a2d", "muted": "#555555"}
    theme = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "omarchy/current/theme/colors.toml"
    try:
        supplied = tomllib.loads(theme.read_text())
        for key in colors:
            if re.fullmatch(r"#[0-9a-fA-F]{6}", str(supplied.get(key, ""))):
                colors[key] = supplied[key]
    except (OSError, ValueError):
        pass
    return colors


def upload_page(image):
    payload = base64.b64encode(image).decode("ascii")
    page = ("""<!doctype html>
<html lang="en"><meta charset="utf-8"><title>Google Lens</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<style>
*{box-sizing:border-box}body{font:15px system-ui;margin:0;padding:28px;
background:__background__;color:__foreground__;min-height:100vh}
header{display:flex;align-items:center;gap:12px;margin-bottom:28px}
.mark{width:36px;height:36px;color:__accent__}h1{font-size:19px;margin:0;font-weight:600}
.caption{margin:5px 0 0;opacity:.7;font-size:12px}
figure{margin:0;background:__lighter_background__;border:1px solid __muted__;padding:12px}
img{display:block;max-width:100%;max-height:52vh;margin:auto;object-fit:contain}
.progress{height:2px;background:__accent__;margin-top:24px}
#status{line-height:1.6;margin:16px 0 6px}footer{font-size:12px;opacity:.65;line-height:1.6}
button{font:inherit;padding:9px 14px;margin-top:22px;border:1px solid __muted__;
background:__lighter_background__;color:__foreground__;cursor:pointer}
button:hover,button:focus-visible{border-color:__accent__;outline:1px solid __accent__}
input{display:none}</style>
<header><svg class="mark" viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
<path d="M11 4H6a2 2 0 0 0-2 2v5m17-7h5a2 2 0 0 1 2 2v5M4 21v5a2 2 0 0 0 2 2h5m10 0h5a2 2 0 0 0 2-2v-5"/>
<circle cx="16" cy="16" r="6"/></svg><div><h1>Google Lens</h1>
<p class="caption">Search what you see</p></div></header>
<figure><img id="preview" alt="Your selected screenshot"></figure>
<div class="progress" role="progressbar" aria-label="Opening visual search"></div>
<p id="status" role="status">Sending your screenshot to Google Lens…</p>
<footer>Results will appear in this window.</footer>
<form id="upload" action="https://lens.google.com/v3/upload?ep=cntpubb&amp;re=df&amp;s=4"
method="post" enctype="multipart/form-data">
<input id="image" type="file" name="encoded_image" accept="image/png">
<button type="submit">Search screenshot again</button></form>
<script>
try {
  const encoded = '""" + payload + """';
  document.getElementById('preview').src = 'data:image/png;base64,' + encoded;
  const bytes = Uint8Array.from(atob(encoded), c => c.charCodeAt(0));
  const transfer = new DataTransfer();
  transfer.items.add(new File([bytes], 'screenshot.png', {type: 'image/png'}));
  document.getElementById('image').files = transfer.files;
  const form = document.getElementById('upload');
  const action = new URL(form.action);
  action.searchParams.set('st', Date.now().toString());
  action.searchParams.set('hl', navigator.language || 'en');
  form.action = action.href;
  form.submit();
} catch (error) {
  document.getElementById('status').textContent =
    'Could not attach the screenshot. Paste it into Google Lens from the clipboard.';
  console.error(error);
}
</script></html>""")
    for key, value in theme_colors().items():
        page = page.replace(f"__{key}__", value)
    return page.encode("utf-8")


def image_dimensions(image):
    if len(image) >= 24 and image[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", image[16:24])
    raise ValueError("The screenshot is not a PNG image.")


def prepare_image(image_path):
    image = Path(image_path).read_bytes()
    if not image:
        raise ValueError("Screenshot must be between 1 byte and 20 MiB.")
    dimensions = image_dimensions(image)
    config_path = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "google-lens/settings.json"
    try:
        config = json.loads(config_path.read_text())
        quality = "original" if isinstance(config, dict) and config.get("quality") == "original" else "balanced"
    except (OSError, ValueError):
        quality = "balanced"
    original_size = len(image)
    if quality == "balanced" and max(dimensions) > 2560 and shutil.which("magick"):
        resized = Path(image_path).with_name("upload.png")
        try:
            subprocess.run(["magick", str(image_path), "-resize", "2560x2560>", "-strip", "-depth", "8",
                            "-define", "png:compression-level=6", str(resized)],
                           check=True, capture_output=True, timeout=15)
            candidate = resized.read_bytes()
            if 0 < len(candidate) < original_size and max(image_dimensions(candidate)) <= 2560:
                image = candidate
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            print(f"Google Lens: resizing failed; using original screenshot ({error}).", file=sys.stderr)
        finally:
            resized.unlink(missing_ok=True)
    return image, {"quality": quality, "original_bytes": original_size,
                   "upload_bytes": len(image), "upload_dimensions": image_dimensions(image)}


def handoff(image_path, profile_dir, log_path):
    started = time.perf_counter()
    image, metrics = prepare_image(image_path)
    if not image or len(image) > 20 * 1024 * 1024:
        raise ValueError("Screenshot must be between 1 byte and 20 MiB.")
    page = upload_page(image)
    route = "/" + secrets.token_urlsafe(32)

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path != route:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(page)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(page)
            self.server.delivered = True

        def log_message(self, *_args):
            pass

        def setup(self):
            super().setup()
            self.connection.settimeout(3)

    # Stop serving once Chromium receives the page, or after 45 seconds on
    # failure. No screenshot or generated HTML is saved in the profile/cache.
    with HTTPServer(("127.0.0.1", 0), Handler) as server:
        server.timeout = 1
        server.delivered = False
        url = f"http://127.0.0.1:{server.server_port}{route}"
        with open(log_path, "ab") as log:
            browser = subprocess.Popen(
                ["node", str(Path(__file__).with_name("google-lens-window.mjs")),
                 url, str(profile_dir)],
                stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                start_new_session=True,
            )
            deadline = time.monotonic() + 45
            while not server.delivered and time.monotonic() < deadline:
                server.handle_request()
                # The controller can exit before Chromium reads the page.
                if browser.poll() not in (None, 0) and not server.delivered:
                    raise RuntimeError(f"Lens window controller failed. See {log_path}.")
            if not server.delivered:
                raise TimeoutError("Chromium did not load the screenshot within 45 seconds.")
    metrics.update({"handoff_seconds": round(time.perf_counter() - started, 3),
                    "recorded_at": datetime.now(timezone.utc).isoformat()})
    # This measures local preparation and browser handoff, not Google's response.
    try:
        destination = Path(log_path).with_name("metrics.json")
        temporary = destination.with_suffix(".tmp")
        temporary.write_text(json.dumps(metrics, indent=2) + "\n")
        temporary.chmod(0o600)
        temporary.replace(destination)
    except OSError as error:
        print(f"Google Lens: could not save timing: {error}", file=sys.stderr)


if __name__ == "__main__":
    try:
        handoff(*sys.argv[1:])
    except (OSError, ValueError, RuntimeError) as error:
        print(f"Google Lens: {error}", file=sys.stderr)
        sys.exit(1)
