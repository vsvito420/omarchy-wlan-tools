<div align="center">

<img src="icon.svg" width="96">

# omarchy-wlan-tools

**A small toolbox for finding out why the Wi-Fi lags: antenna alignment, a live radar of all clients, packet loss, per-device tests and a Wi-Fi 6E vs 7 A/B test.**
For [Omarchy](https://omarchy.org) / any Linux with `iw`. The UI is German.

[![Omarchy](https://img.shields.io/badge/Omarchy-Hyprland-1793d1?style=for-the-badge&logo=archlinux&logoColor=white)](https://omarchy.org)
[![Python](https://img.shields.io/badge/Python-stdlib_only-3776ab?style=for-the-badge&logo=python&logoColor=white)](#requirements)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Deutsch](https://img.shields.io/badge/lies_mich-Deutsch-black?style=for-the-badge)](README.de.md)

</div>

---

![wlan-graph radar (demo data, random network names)](screenshots/wlan-graph.png)
*`wlan-graph --demo`: made-up devices and random network names*

## The tools

| Command | Launcher | What it does | Needs router SSH |
|---|---|---|---|
| `antenne` | WLAN Antenne | Terminal score for the PC's antennas: PHY rate, spatial streams, per-chain dBm, MCS history ([own repo](https://github.com/vsvito420/omarchy-antenne)) | no |
| `wlan-graph` | WLAN Graph | Web radar of every client on the router: distance from the center = signal, one sector per network, colored by band | yes |
| `wlan-graph --ausrichten` | WLAN Antenne ausrichten | Align the **router** antennas: one candle chart per position, better/worse vs the previous one (fair: only devices seen in both), top score | yes |
| `wlan-graph --lan` | – | Same page for your phone on the home network (secret link + QR code, port 8775) | yes |
| `wlan-loss` | WLAN Paketverlust | Live packet loss and lag spikes: pings router, ISP hop, a Valve CS2 relay and 1.1.1.1 side by side, marks Wi-Fi scans and router retries, logs CSV | optional |
| `wlan-test [ip\|name\|mac]` | WLAN Gerätetest | One-shot test of any device: pings it and diffs the router counters → retries and loss in both directions | yes |
| `wlan-vergleich` | WLAN Vergleich 6E/7 | Fair A/B test Wi-Fi 6E vs Wi-Fi 7 (Intel BE200, `disable_11be`): ping, jitter, speed to a wired server, recommendation | yes + server |
| `wifimon` | WLAN Router-Monitor | Live signal monitor for this PC, running on the router (`router/wifimon.sh`) | yes |

## Install

```bash
git clone https://github.com/vsvito420/omarchy-wlan-tools
cd omarchy-wlan-tools
./install.sh            # asks for router address / SSH user / port once
wlan-graph --demo       # try it without a router
```

Settings live in `~/.config/wlan-tools/config` (see [`config.example`](config.example)). Without it the default gateway is used.
Logs go to `~/.local/state/wlan-*`. Remove with `./uninstall.sh`.

## Requirements

- Python 3 (standard library only), `iw`, `iproute2`, `ping`, `ssh`; `qrencode` optional for `--lan`
- For the router tools: an **ASUS router with Qualcomm Wi-Fi** (`wlanconfig`, `apstats`, `ath*` interfaces), SSH enabled with key login
- `wifimon`: copy `router/wifimon.sh` to the router (e.g. `/jffs/wifimon.sh`)
- `wlan-vergleich`: Intel Wi-Fi 7 card (iwlwifi), sudo, and a wired Linux box with `python3` reachable via SSH key (`SERVER=` in the config)
- `wlan-graph --lan`: open port 8775 for your LAN, e.g. `sudo ufw allow from 192.168.1.0/24 to any port 8775 proto tcp`

## How it works

- Router data comes from one SSH call per refresh (`ControlMaster` keeps the connection open): `iwconfig` per `ath*` interface, `wlanconfig list sta`, dnsmasq leases, ARP.
- Wi-Fi 7 MLO clients show a random link address; `wlan-graph` maps it back to the real MAC via the `MLD Addr` line.
- `wlan-graph` serves a single HTML page from a tiny local server (127.0.0.1:8765), opens it as an Omarchy web app and exits after 45 s without requests.
- `wlan-test` reads `apstats -v -i <vap> -R` before and after a ping burst, so it also works when a device is listed on two bands.

## License

MIT · Deutsch & English
