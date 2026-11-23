# omarchy-google-lens

A lightweight Google Lens screen snip and visual search overlay for Omarchy and Hyprland on Wayland.

## Features

- **Multi-Monitor Snip**: Freezes and crops any region or window across all screens using `omarchy-capture-region` / `grim`.
- **Floating Overlay**: Launches Google Lens as a pinned, chromeless window docked on the right side over your active window.
- **Fast Upload**: Uses direct HTTP/1.1 endpoint uploads for fast response.
- **Clipboard Sync**: Automatically copies the snip to the clipboard (`wl-copy`) for pasting with <kbd>Ctrl</kbd> + <kbd>V</kbd>.
- **Quick Dismiss**: Close the overlay anytime with <kbd>Super</kbd> + <kbd>Q</kbd> or <kbd>Ctrl</kbd> + <kbd>W</kbd>.

## Installation

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
