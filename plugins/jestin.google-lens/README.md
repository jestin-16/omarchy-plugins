# omarchy-google-lens

A lightweight Google Lens screen snip and visual search overlay for Omarchy and Hyprland on Wayland.

An optional [native Lensdesk preview](native/README.md) now provides an embedded
results panel, clipboard/file/drop input, crop/undo, and local text extraction.
It is installed separately and does not replace this launcher until its live
Google compatibility has been verified. See [CHECKPOINT.md](CHECKPOINT.md) for
the implementation status and resume instructions.

## Features

- **Multi-Monitor Snip**: Freezes and crops any region or window across all screens using `omarchy-capture-region` / `grim`.
- **Floating Overlay**: Launches Google Lens as a pinned, chromeless window docked on the right side over your active window.
- **Automatic Upload**: Submits the screenshot directly from Chromium to Google Lens, keeping upload cookies and redirects in the same browser session.
- **Clipboard Sync**: Automatically copies the snip to the clipboard (`wl-copy`) for pasting with <kbd>Ctrl</kbd> + <kbd>V</kbd>.
- **Quick Dismiss**: Close the overlay anytime with <kbd>Super</kbd> + <kbd>Q</kbd> or <kbd>Ctrl</kbd> + <kbd>W</kbd>.
- **Unobstructed Capture**: Hides the existing Lens window during selection and restores it on success, cancellation, or failure.
- **Theme-aware Upload**: Uses Omarchy's current colors, with a screenshot preview and a dedicated launcher icon.
- **Memory Modes**: Keep hidden results ready, or close them gracefully after five minutes hidden.

## Installation

Requires Omarchy's region picker, `grim`, `wl-copy`, `chromium`, `python3`,
`hyprctl`, `flock` (util-linux), and Node.js 22 or newer.
ImageMagick (`magick`) optionally reduces oversized uploads.

```bash
git clone https://github.com/jestin-16/omarchy-google-lens.git
cd omarchy-google-lens
./install.sh
```

### Keybindings

Add to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + L", "Google Lens", "/home/jestin/.local/bin/google-lens")
o.bind("SUPER + SHIFT + PRINT", "Google Lens", "/home/jestin/.local/bin/google-lens")
```

### Hyprland Window Rules

Add to `~/.config/hypr/hyprland.lua`:

```lua
o.window("(^chrome-lens\\.google\\.com__.*$|^chrome-images\\.google\\.com__.*$|^chrome-www\\.google\\.com__.*$)", {
  tag = "-chromium-based-browser",
  float = true,
  pin = true,
  size = { "(monitor_w*0.42)", "(monitor_h*0.88)" },
  move = { "(monitor_w*0.58-20)", "(monitor_h*0.06)" },
})
```

Reload Hyprland:
```bash
hyprctl reload
```

## Daily use and performance

| Command | Effect |
| --- | --- |
| `google-lens` | Select a region and reuse the results window |
| `google-lens toggle` | Hide or restore existing results without recapturing |
| `google-lens mode low-memory` | Close results after they have been explicitly hidden for five minutes |
| `google-lens mode fast` | Keep hidden results ready until you close them (default) |
| `google-lens quality balanced` | Reduce uploads larger than 2560 pixels on either axis, if ImageMagick is available (default) |
| `google-lens quality original` | Preserve full resolution, useful for very small text |
| `google-lens status` | Show preferences and the latest local handoff timing and image sizes |

Preferences are stored in `~/.config/google-lens/settings.json`; XDG paths are
honored. The launcher entry also offers Show / hide results and memory-mode
actions. Closing with Super+Q or Ctrl+W closes normally; use `toggle` to keep the
window available in the background. The idle timer only applies to explicitly
hidden windows, never visible results or verification pages. It runs only in
low-memory mode while results are hidden, checks every 15 seconds, and does not
close a window during capture.

Captures are hidden in a dedicated Hyprland special workspace while selecting.
The prior workspace and pin state are restored; resizing and moving the existing
window is left to the compositor. Other browser windows are not moved. If the
compositor fails during restoration, terminal output gives the recovery file;
run `python3 ~/.local/libexec/google-lens-desktop.py restore /path/to/windows.json`
once Hyprland is responding again.

Balanced quality only changes the upload, and keeps the original if conversion
would increase the file size. The clipboard keeps the original PNG.
Small captures are not reencoded. Local measurements in
`~/.local/state/google-lens/metrics.json` contain timing, dimensions, and byte
counts, not screenshot content or search URLs. `handoff_seconds` measures image
preparation and delivery to Chromium, not time spent selecting or Google's
response time. The Google results page itself is not restyled.

## Upload flow and troubleshooting

The launcher opens a short-lived page on `127.0.0.1` with an unpredictable URL.
It attaches the PNG screenshot to a form and automatically submits it to Google's
Lens upload endpoint. The local server stops when Chromium receives the page;
the temporary screenshot is then deleted. No generated upload page is saved to
disk. Google receives the selected screenshot, and the clipboard retains a copy.
The Chromium profile remains in `~/.config/google-lens/profile`.

Further captures reuse and focus the existing Lens window. The plugin enables
Chromium's local debugging connection only for this dedicated profile, and uses
it to navigate that window to the next upload. Cookies and verification state
stay in the same profile. Google may still ask you to complete a CAPTCHA manually.
After upgrading from the old launcher, **close all existing Lens windows once**
before starting a new search so the browser can enable window reuse.

This uses the browser form flow in [Chromium's Lens implementation](https://chromium.googlesource.com/chromium/src/+/HEAD/chrome/browser/resources/new_tab_page/lens_form.ts).
It replaces the previous `curl` upload and redirect parsing, which could silently
open Google Images without submitting the screenshot. Network failures or Google
consent/challenge pages now appear in the browser itself.

Run `google-lens` from a terminal to see capture or launch errors. Browser output
is logged to `~/.local/state/google-lens/browser.log` (or `$XDG_STATE_HOME/google-lens/browser.log`).
Press Escape to cancel a selection. Re-run `./install.sh` after updating; the
launcher now requires the helper installed in `~/.local/libexec`.

Run the regression checks with `python3 -m unittest discover -s tests -v` and
`node tests/test_window.mjs`. Desktop and Google connectivity still require
a live smoke test.
