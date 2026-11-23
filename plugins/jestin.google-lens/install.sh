#!/bin/bash
set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DEST="${HOME}/.local/bin"
LIBEXEC_DEST="${HOME}/.local/libexec"
APP_DEST="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"
ICON_DEST="${XDG_DATA_HOME:-${HOME}/.local/share}/icons/hicolor/scalable/apps"

echo "Installing Google Lens overlay plugin..."

mkdir -p "$BIN_DEST" "$LIBEXEC_DEST" "$APP_DEST" "$ICON_DEST"
install -m 755 "${REPO_DIR}/bin/google-lens" "${BIN_DEST}/google-lens"
install -m 644 "${REPO_DIR}/libexec/google-lens-upload.py" "${LIBEXEC_DEST}/google-lens-upload.py"
install -m 644 "${REPO_DIR}/libexec/google-lens-window.mjs" "${LIBEXEC_DEST}/google-lens-window.mjs"
install -m 644 "${REPO_DIR}/libexec/google-lens-desktop.py" "${LIBEXEC_DEST}/google-lens-desktop.py"
ln -sf "${BIN_DEST}/google-lens" "${BIN_DEST}/omarchy-capture-lens"
install -m 644 "${REPO_DIR}/share/applications/google-lens.desktop" "${APP_DEST}/google-lens.desktop"
install -m 644 "${REPO_DIR}/share/icons/google-lens.svg" "${ICON_DEST}/google-lens.svg"

echo "Installed binary to ${BIN_DEST}/google-lens"
echo "Installed desktop entry to ${APP_DEST}/google-lens.desktop"
echo "Done. Configure keybinding in ~/.config/hypr/bindings.lua and rules in ~/.config/hypr/hyprland.lua"
