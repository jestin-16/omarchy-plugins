# Local media card customization

Extends the existing jestin.media clone of omarchy.media.

- Flat black player with a thin theme-accent border and selectable source rows.
- Volume and lyrics expand from the footer; both start collapsed.
- Volume slider (0–100%) and mute button.
- System output volume uses Omarchy’s PanelSlider and Quickshell PipeWire.
- Synced lyrics reuse crmne/omarchy-lyrics’s MIT model, HTTPS fetcher and cache.
- Click a synced line to seek. Plain lyrics can be scrolled manually.
- Lyrics on/off is saved in ~/.local/state/omarchy/media-card.ini.
- With lyrics on, expanding the lyrics section looks up artist/title/album/duration at
  https://lrclib.net. Closing it cancels pending requests. No polling while closed.
- Lyrics availability and timing depend on LRCLIB’s recording coverage.

Vendored source provenance is in vendor/lyrics/NOTICE.md. Changes here are local
and are not updated by `omarchy plugin update crmne.lyrics`.

Validation: `node --test tests/lyrics.test.cjs`, `omarchy plugin validate .`.

Backup before this change: /home/jestin/.config/omarchy/backups/media-glow-lyrics-20261117-162939/jestin.media

Backup before the compact redesign: /home/jestin/.config/omarchy/backups/media-before-clean-20261117-165110/jestin.media

Visual refinement: dark blue selected player, artwork outline, stronger title,
subtle hover feedback and keyboard-focusable controls.
Backup before refinement: /home/jestin/.config/omarchy/backups/media-before-polish-20261117-165328/jestin.media

Motion: directional popup entrance, expanding/fading drawers, track-change
transition, artwork fade-in, eased seek progress, and selection/lyric highlights.
All durations follow Omarchy reduced motion; no continuous decorative loops.
Backup before motion: /home/jestin/.config/omarchy/backups/media-before-motion-20261117-165655/jestin.media
