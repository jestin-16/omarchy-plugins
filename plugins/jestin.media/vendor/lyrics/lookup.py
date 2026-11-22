"""Adapt crmne.lyrics' existing fetcher for the embedded media card."""
import os
from pathlib import Path
import runpy
from types import SimpleNamespace

lib = runpy.run_path(str(Path(__file__).parent / "bin" / "lrclib"))
args = SimpleNamespace(
    artist=os.environ.get("LRCLIB_ARTIST", "")[:512],
    title=os.environ.get("LRCLIB_TITLE", "")[:512],
    album=os.environ.get("LRCLIB_ALBUM", "")[:512],
    duration=float(os.environ.get("LRCLIB_DURATION", "0")),
    no_cache=os.environ.get("LRCLIB_REFRESH") == "1",
    ttl=30 * 86400,
)
try:
    payload = lib["cmd_get"](args)
    if not payload.get("result"):
        payload = lib["cmd_search"](args)
except Exception as exc:
    payload = {"ok": False, "error": str(exc)[:512]}
print(lib["encode"](payload))
