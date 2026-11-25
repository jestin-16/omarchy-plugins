# MSI cooling presets

Personal setup for **user `jestin` on an MSI GF63 Thin 11UC**, with Omarchy,
`msi-ec`, and power-profiles-daemon already installed. Paths, Polkit authorization,
and the keyboard hardware match deliberately target that setup.

| Mode | Behavior |
| --- | --- |
| Quiet | Power Saver profile; firmware-controlled automatic fans |
| Balanced | Balanced profile; automatic fans |
| Dynamic | Balanced normally; reduce power and add boost when heat persists |
| Boost | Balanced profile; Cooler Boost on |

The controller samples the maximum valid CPU temperature and the available MSI
GPU temperature every five seconds. Dynamic selects Power Saver after at least
15 seconds at 80°C or above, and adds boost after at least 10 seconds at 86°C or
above. It returns to Balanced after 30 seconds at 72°C or below, with a minimum
60-second boost run to avoid rapid fan changes.

At 92°C or after 10 seconds without usable CPU temperature readings, every mode
uses Power Saver and boost. That override clears after at least 30 seconds at
78°C or below and at least 60 seconds of protection. These are personal policy
defaults, not MSI-specified thresholds or a replacement for firmware protection.

The selected preset owns the active power profile while the service runs. The
controller checks for profile changes every 30 seconds, including changes made
by charger/battery switching. It does not change CPU voltage or use raw EC writes.

## Install on this machine

Back up existing files in the destinations before copying this source snapshot.
From the repository root:

```bash
mkdir -p ~/.local/share/msi-cooling ~/.local/bin
cp -a tools/msi-cooling/. ~/.local/share/msi-cooling/
install -m 0755 tools/msi-cooling/bin/msi-cooling ~/.local/bin/msi-cooling
install -m 0755 tools/msi-cooling/bin/msi-cooler-boost ~/.local/bin/msi-cooler-boost
```

Add the contents of `bindings.lua` to `~/.config/hypr/bindings.lua`, replacing any
older cooling bindings rather than duplicating them. Then run as Jestin, without
prefixing the setup command with sudo:

```bash
bash ~/.local/share/msi-cooling/setup.sh
```

The installer asks for sudo to install a root-owned controller, system service,
narrow Polkit action, and model-specific keyboard mapping. It saves replaced
system files under `/var/lib/msi-cooling/install-backup.*`, enables the service at
boot, reloads Hyprland, and checks controller health. The initial mode is Dynamic;
subsequent selections persist in `/var/lib/msi-cooling/mode.json`.

Fn+F7 maps scan `0x8a` to Linux keycode 202 (`XF86Launch3`). After first installing
that mapping, save work and log out/in once if the running desktop does not see
the new key capability. Super+F7 works without that hardware mapping.

## Shortcuts and commands

| Shortcut | Action |
| --- | --- |
| Fn+F7 or Super+F7 | Cycle Quiet → Balanced → Dynamic → Boost → Quiet |
| Super+Shift+F7 | Same cycle |
| Super+Ctrl+F7 | Select Dynamic |
| Super+Alt+F7 | Show applied mode and sampled temperature/fan speed |

`msi-cooling quiet`, `balanced`, `dynamic`, and `boost` select modes directly.
`msi-cooling toggle` temporarily selects Boost and returns to the previous preset
when repeated. `msi-cooler-boost` is retained as a compatibility command for that
toggle; the F7 bindings use `cycle` instead.

Selection notifications appear immediately and replace the recent cooling toast.
They acknowledge the saved selection; hardware follows on the next controller
tick. Temperature and fan RPM appear only in the status view, because fans take
time to speed up or slow down.

To stop automatic control and restore automatic fans plus Balanced power:

```bash
sudo systemctl disable --now msi-cooling.service
```

Diagnostic commands:

```bash
systemctl status msi-cooling.service
journalctl -u msi-cooling.service -n 30 --no-pager
msi-cooling status
sudo python3 ~/.local/share/msi-cooling/check-fn-f7.py
```

The keyboard diagnostic observes only the mapped key for 12 seconds and does not
grab or change the keyboard.

## Tests

```bash
python3 tools/msi-cooling/test_controller.py
python3 tools/msi-cooling/test_frontend.py
```

Tests use simulated sensors, temporary files, and mocked notification/privilege
commands. They do not change the real laptop's fans or power profile.
