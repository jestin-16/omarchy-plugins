# Google Lens implementation checkpoint

Updated: 2026-11-23. User requested continued improvements and a resumable checkpoint before session limits.

## Stable launcher

The installed launcher lives in `~/.local/bin/google-lens`; helpers are in
`~/.local/libexec`. This repository is the source. A mirrored distribution lives
in `~/Projects/omarchy-plugins/plugins/jestin.google-lens`.

Implemented: browser-submitted screenshot upload, single-window reuse, retained
Chromium profile, hide/restore during capture, reversible hide/show, low-memory
mode (five minutes explicitly hidden), balanced upload resizing, themed upload
preview, launcher icon/actions, local timing/size metrics, and regression tests.

Validation: 24 Python tests and six Node tests pass. Shell syntax and desktop
entry validation pass. User confirmed Google search works; CAPTCHA is manual.
New desktop behavior cannot be tested live from this tool sandbox: Wayland,
Hyprland, loopback sockets, and outbound networking are restricted. Do not claim
live verification or measured Google latency.

Current preferences: low-memory mode and balanced quality. Main shortcut remains
Super+Shift+L. Installation backups are under `~/.local/state/google-lens/backup-*`.

## Native preview checkpoint

The stable launcher checkpoint is Git commit `f1bb1d7`.

Built the optional `native/` C++/Qt Quick/Qt WebEngine application, `lensdesk`.
Implemented persistent controls and image preview, screenshot/clipboard/file/drop
input, crop/undo, local Tesseract OCR, navigation/retry/open-in-browser, a persistent
isolated web profile, one-instance local IPC, a hidden-browser unload timer,
saved window geometry, live Omarchy accent/language support, and headless
dependency diagnostics.

The native sources compile with qmake6 and make. Qt tests report 15 passes
(including setup/cleanup): file validation, unchanged originals, crop/undo,
settings, URL validation, a real Tesseract run, cancelled capture recovery, and
mouse-driven cropping in the actual QML. All 30 stable-launcher checks pass too.
Real QML screenshots were rendered and visually inspected in English and Danish.
`native/docs/preview.png` uses invented sample content and the default accent.

The optional preview is installed at `~/.local/bin/lensdesk`, with launcher entry
`~/.local/share/applications/lensdesk.desktop` (Lensdesk Preview). Its dependency
check passes. No keyboard bindings were changed. The original `google-lens`
command and Chromium profile remain the stable/default route.

An Arch package was built successfully at
`native/pkgbuild/lensdesk-0.1.0-1-x86_64.pkg.tar.zst`. The package is a local build
artifact, ignored by Git. It is not installed system-wide or published. The
user-level preview can be reinstalled with `native/bin/install-user`.

The native renderer, Google upload/CAPTCHA, portal chooser, native single-instance
IPC, compositor pinning/geometry, and hide/reopen browser behavior still need a
live desktop test. The tool sandbox blocks live desktop/network sockets. The
offline UI preview deliberately does not start WebEngine, and must not be treated
as proof that native Google integration works. Do not promote it to the default
until the live acceptance checklist in `native/README.md` is completed.

Native data and cookies live under `~/.local/share/lensdesk`, separately from the
old Chromium profile. Local input is not uploaded until Search, except New capture
which automatically searches, matching the existing workflow. `lensdesk --text`
captures for local OCR only. No screenshot history is implemented.

## Next steps on a live desktop

1. Launch `lensdesk`, load a sample file, and click Search. Complete CAPTCHA if
   Google asks. Test a second capture in the same window.
2. Verify native portal file selection, clipboard/drop, pinning, multi-monitor
   geometry, hidden timeout, and restoring the renderer after five minutes.
3. Compare actual cold/repeated search time and process memory with the stable
   launcher. No native performance superiority has been measured or claimed.
4. Resolve compatibility findings before deciding whether to wire the existing
   shortcut to the native version. Keep screenshot history off unless requested.

## Resume checks

```sh
python3 -m unittest discover -s tests -v
node tests/test_window.mjs
bash -n bin/google-lens install.sh
desktop-file-validate share/applications/google-lens.desktop
git status --short
native/bin/test
native/build/lensdesk --check --json
```

Build: `native/bin/build`. Offline preview:

```sh
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
QT_QUICK_BACKEND=software native/build/lensdesk --preview \
  --language en --screenshot /tmp/lensdesk-preview.png
```

The explicit generic Qt platform theme prevents the installed GTK theme plugin
from trying to connect to the live display during an offscreen test.

No remote publication or push is authorized. Local Git checkpoints are used to
preserve completed stages. A native prototype must not silently become the
default launcher before live compatibility validation.
