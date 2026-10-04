#!/bin/bash
# Remove the WLAN tools and their launchers (keeps ~/.config/wlan-tools and ~/.local/state/wlan-*).
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
for t in antenne wlan-graph wlan-loss wlan-test wlan-vergleich wifimon; do rm -f "$HOME/.local/bin/$t"; done
for f in wlan-antenne wlan-graph wlan-ausrichten wlan-loss wlan-test wifimon wlan-vergleich; do rm -f "$DATA/applications/$f.desktop"; done
update-desktop-database "$DATA/applications" 2>/dev/null || true
echo "Removed the WLAN tools."
