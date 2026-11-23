#!/bin/bash
set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DEST="${HOME}/.local/bin"
APP_DEST="${HOME}/.local/share/applications"

echo "Installing Google Lens overlay plugin..."

mkdir -p "$BIN_DEST" "$APP_DEST"
install -m 755 "${REPO_DIR}/bin/google-lens" "${BIN_DEST}/google-lens"
ln -sf "${BIN_DEST}/google-lens" "${BIN_DEST}/omarchy-capture-lens"
install -m 644 "${REPO_DIR}/share/applications/google-lens.desktop" "${APP_DEST}/google-lens.desktop"

echo "Installed binary to ${BIN_DEST}/google-lens"
echo "Installed desktop entry to ${APP_DEST}/google-lens.desktop"
echo "Done. Configure keybinding in ~/.config/hypr/bindings.lua and rules in ~/.config/hypr/hyprland.lua"
