# Jestin Notifications

A personal copy of `omarchy.notifications` from Omarchy 4.5.0-3. Original author
metadata and source copyright notices are retained; see the repository's
`LICENSE-OMARCHY` and the Omapager attribution in `Service.qml`.

![Notification card preview](preview.png)

Changes from the stock plugin:

- Rounded 364 px cards with a thin accent stripe, smaller icons, and separate
  source, title, and body text. Colors follow the active Omarchy theme.
- 140 ms entrance and 90 ms exit animations; replacements update immediately.
- Positive sender timeouts are honored between 750 ms and 30 seconds. Defaults
  are 3 seconds for low urgency and 4.5 seconds for normal urgency.
- Critical alerts remain until dismissed. Restored ordinary alerts get 5 seconds.
- Two visible cards per collapsed stack, with less overlap.

Actions, keyboard navigation, notification history, Do Not Disturb, safe markup
handling, and source grouping retain the original implementation.

## Installation

From the repository root, back up any existing personal copy before replacing it:

```bash
cp -a plugins/jestin.notifications ~/.config/omarchy/plugins/
omarchy-shell shell rescanPlugins
omarchy plugin enable jestin.notifications
```

Enabling this clone replaces the built-in notification service. Omarchy watches
the plugin directory and reloads edits. To return to the original service:

```bash
omarchy plugin disable jestin.notifications
```

## Validation

```bash
node plugins/jestin.notifications/tests/notifications.test.cjs
```

The checks cover timeout handling, persistent critical alerts, restored messages,
markup safety, and stack layout. Cards were also rendered in an offscreen
Quickshell preview, then confirmed on the live desktop.
