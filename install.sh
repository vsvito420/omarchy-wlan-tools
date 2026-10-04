#!/bin/bash
# Install all WLAN tools for the current user:
#   ~/.local/bin/{antenne,wlan-graph,wlan-loss,wlan-test,wlan-vergleich,wifimon}
#   ~/.local/share/applications/wlan-*.desktop   launchers (Super + Space → "WLAN …")
#   ~/.config/wlan-tools/config                   router settings (created from config.example)
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN="$HOME/.local/bin"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/wlan-tools/config"
TOOLS="antenne wlan-graph wlan-loss wlan-test wlan-vergleich wifimon"

for cmd in python3 iw ip ping ssh; do
  command -v "$cmd" >/dev/null || { echo "Missing: $cmd (sudo pacman -S iw iproute2 iputils python openssh)"; exit 1; }
done

mkdir -p "$BIN" "$DATA/applications" "$(dirname "$CONF")"
for t in $TOOLS; do install -m 755 "$SRC/$t" "$BIN/$t"; done
for f in "$SRC"/applications/*.desktop; do
  sed "s|@BIN@|$BIN|g" "$f" >"$DATA/applications/$(basename "$f")"
done
update-desktop-database "$DATA/applications" 2>/dev/null || true

if [ ! -f "$CONF" ]; then
  gw=$(ip -4 route show default | awk '{print $3; exit}')
  read -rp "Router address [$gw]: " host
  read -rp "Router SSH user [admin]: " user
  read -rp "Router SSH port [22]: " port
  read -rp "Wired server for wlan-vergleich (user@ip, empty = skip): " server
  sed -e "s|^ROUTER_HOST=.*|ROUTER_HOST=${host:-$gw}|" -e "s|^ROUTER_USER=.*|ROUTER_USER=${user:-admin}|" \
      -e "s|^ROUTER_PORT=.*|ROUTER_PORT=${port:-22}|" -e "s|^SERVER=.*|SERVER=$server|" \
      "$SRC/config.example" >"$CONF"
  chmod 600 "$CONF"
fi

echo "Installed: $TOOLS"
echo "Settings: $CONF"
echo "Router monitor: copy router/wifimon.sh to the router, e.g."
echo "  scp -P <port> router/wifimon.sh <user>@<router>:/jffs/wifimon.sh"
echo "Try it without a router: wlan-graph --demo"
