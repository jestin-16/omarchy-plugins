# Jestin's Omarchy plugins

Personal Omarchy shell plugin customizations, preserved as source. These plugins
extend Omarchy's Quickshell desktop and require a compatible Omarchy installation.

## Custom plugins

| Folder | Purpose |
| --- | --- |
| `plugins/jestin.agents` | Agent usage and subscription panel |
| `plugins/jestin.breathing-borders` | Breathing opacity for panel borders |
| `plugins/jestin.google-lens` | Google Lens screen snip and floating visual search overlay |
| `plugins/jestin.lock` | Custom lock screen with companion and status components |
| `plugins/jestin.media` | Media service and now-playing widget with synced lyrics |
| `plugins/jestin.menu` | Compact searchable Omarchy menu |
| `plugins/jestin.network` | Wi-Fi list and connection state widget |
| `plugins/jestin.notifications` | Compact notification cards, faster updates, and shorter timeouts |
| `plugins/jestin.workspaces` | Workspace indicators |

These are personal copies of Omarchy plugins, with their original author and
`clonedFrom` metadata retained. Their presence here does not mean they are all
currently enabled. In particular, the custom menu and lock screen are alternatives
to other launchers and lock screens.

## Install a custom plugin

This repository contains multiple plugins, so do **not** pass its root URL to
`omarchy plugin add`, which expects one root-level manifest.

Clone this repository, then copy the plugin you want into your user plugin
directory. For example, from this repository's root, on a machine where the
destination does not already exist:

```bash
mkdir -p ~/.config/omarchy/plugins
cp -a plugins/jestin.media ~/.config/omarchy/plugins/
omarchy plugin validate ~/.config/omarchy/plugins/jestin.media
omarchy-shell shell rescanPlugins
omarchy plugin enable jestin.media
```

Back up an existing plugin directory before replacing it. Enable only the plugins
you want; cloned plugins can replace their built-in counterparts. Configure bar
placement through Omarchy. Review lock-screen compatibility before enabling a
replacement lock service.

## Cooling controls

[`tools/msi-cooling`](tools/msi-cooling/README.md) preserves the Quiet, Balanced,
Dynamic, and Boost presets, the temperature controller, and the Fn+F7/Super+F7
mode cycle. This is a personal setup for Jestin's MSI GF63 Thin 11UC, not a generic
fan-control installer. Its README covers installation, thresholds, and stopping
the service.

## Notification changes

[`plugins/jestin.notifications`](plugins/jestin.notifications/README.md) replaces
the built-in notification service through Omarchy's clone mechanism. It keeps
notification actions, history, and Do Not Disturb, while using compact cards,
shorter animations, immediate replacements, and sender-requested timeouts.

## Changes to third-party plugins

`patches/` preserves local changes to Lock Screen Explorer, OmaControl, and
Omascreentime. Each directory includes:

- `upstream.json`: original repository and exact base commit.
- `changes.patch`: modifications to tracked files.
- `added-files/`, when present: new source files to copy over the upstream tree.
- The upstream license where available.

To restore a patch, clone its upstream repository into a separate working folder,
check out the recorded base commit, then apply `changes.patch` with
`git apply --check` followed by `git apply`. Copy the contents of `added-files/`
into that checkout if present. Follow that project's installation instructions.
Patches against newer upstream versions may need changes.

## Scope and attribution

This snapshot includes plugin source, the cooling tool, and local upstream modifications. It excludes
credentials, usage histories, caches, desktop settings, and unmodified installed
third-party plugins. Runtime code may read credentials or usage records locally;
those records are not included in this repository.

`snapshot.json` records the included plugin versions, tools, and patch baselines.
Plugins with `clonedFrom` metadata derive from [Omarchy](https://github.com/omacom/omarchy), by David
Heinemeier Hansson, under the MIT license reproduced in `LICENSE-OMARCHY`.
Third-party patches retain the upstream authorship and license notices.

This is a source backup, not a compatibility certification for newer Omarchy
versions. Plugin manifests were validated when the snapshot was prepared.
