# Minimalist Omarchy Menu (Super+Space)

A clean, modern, aesthetic Spotlight-style launcher for Omarchy and Hyprland. Bound to `Super+Space` and the bar menu icon via `jestin.menu` (`clonedFrom: omarchy.menu`).

## Design Highlights
- **Minimalist Aesthetic**: 460px focused width, rounded card (16px radius), subtle 1px border with soft scrim background matching the active theme (e.g., Tokyo Night).
- **Search-First Workflow**: Seamless search bar at the top with a subtle accent icon (`󰍉`), clear placeholder (`Search apps, commands & settings…`), and an interactive `esc` badge.
- **Instant Search**: All desktop applications, utilities, settings, and commands are indexed immediately on open. Just press `Super+Space`, start typing, and hit `Enter`.
- **Curated Root Menu**: Clean, uncluttered list of essential sections (Applications, Quick Actions, Window Overview, Appearance, Settings, Utilities, System) that fits comfortably without scrolling.
- **Sleek Row Selection**: Soft pill highlight with a subtle vertical accent indicator on the selected row, crisp icon alignment, and an interactive `↵` indicator for actions.

## Customization
- Edit `command-center.json` to customize items and actions; updates reload automatically.
- User extensions in `~/.config/omarchy/extensions/omarchy-menu.jsonc` take precedence and are merged seamlessly.

To restore the stock Omarchy menu:
```sh
omarchy plugin enable omarchy.menu
```
