# WLAN-Werkzeugkasten

<img src="https://raw.githubusercontent.com/vsvito420/omarchy-wlan-tools/main/icon.svg" width="72">

Alles, womit ich herausgefunden habe, warum das WLAN in CS2 laggt – zusammen in einem Repo, mit einem `install.sh`.
Die meisten Tools fragen den Router per SSH ab (ASUS mit Qualcomm-WLAN). `antenne` braucht keinen Router.

![WLAN-Graph mit Demo-Daten](https://raw.githubusercontent.com/vsvito420/omarchy-wlan-tools/main/screenshots/wlan-graph.png)
*`wlan-graph --demo` – erfundene Geräte, zufällige Netznamen*

## Was drin ist

- **`antenne`** (WLAN Antenne) – PC-Antennen ausrichten, siehe [[WLAN-Antennen ausrichten]]
- **`wlan-graph`** (WLAN Graph) – Radar aller Geräte am Router
  - Abstand zur Mitte = Empfang, Ringe in dBm, grün/gelb/rot
  - ein Sektor je Netz, Farbe = Band (2,4 / 5 / 6 GHz)
  - `--ausrichten`: **Router**-Antennen ausrichten – Kerze je Position, besser/schlechter, Topscore
  - `--lan`: dieselbe Seite fürs Handy (geheimer Link + QR-Code)
  - `--demo`: ohne Router ausprobieren
- **`wlan-loss`** (WLAN Paketverlust) – Paketverlust und Lag-Spitzen live
  - Router, Provider, Valve-CS2-Relay und 1.1.1.1 nebeneinander
  - WLAN-Scans und Router-Wiederholungen markiert, CSV-Log
- **`wlan-test`** (WLAN Gerätetest) – ein Gerät testen (IP, Name oder MAC)
  - Pings hin, Router-Zähler vorher/nachher → Wiederholungen und Verlust in beide Richtungen
- **`wlan-vergleich`** (WLAN Vergleich 6E/7) – fairer A/B-Test Wi-Fi 6E gegen Wi-Fi 7
  - schaltet `disable_11be` selbst um, misst Ping, Jitter und Speed zu einem Rechner per Kabel
- **`wifimon`** (WLAN Router-Monitor) – Live-Signal dieses PCs, läuft auf dem Router

## Installieren

```bash
git clone https://github.com/vsvito420/omarchy-wlan-tools.git
cd omarchy-wlan-tools
./install.sh            # fragt einmal Router-Adresse, SSH-Benutzer und Port
wlan-graph --demo       # ohne Router ausprobieren
```

- Einstellungen: `~/.config/wlan-tools/config` – ohne Datei wird das Standard-Gateway genommen
- `wifimon`: `router/wifimon.sh` auf den Router kopieren (z. B. `/jffs/wifimon.sh`)
- Entfernen mit `./uninstall.sh`

## So funktioniert's

- **Code:** [`wlan-graph`](https://github.com/vsvito420/omarchy-wlan-tools/blob/main/wlan-graph) – nur Python-Standardbibliothek
- pro Aktualisierung ein SSH-Aufruf zum Router (`ControlMaster` hält die Verbindung offen)
  - `iwconfig` je `ath*`, `wlanconfig list sta`, dnsmasq-Leases, ARP
- Wi-Fi-7-MLO-Geräte melden eine zufällige Link-Adresse → über `MLD Addr` der echten MAC zugeordnet
- `wlan-graph` startet einen Mini-Server auf 127.0.0.1, öffnet ihn als Omarchy-Web-App und beendet sich nach 45 s ohne Abruf
- `wlan-test` liest `apstats -v -i <vap> -R` – klappt auch, wenn ein Gerät auf zwei Bändern gelistet ist

<div class="callout tip" markdown="1">
Fürs Handy-Radar (`wlan-graph --lan`) Port 8775 im Heimnetz freigeben, z. B.
`sudo ufw allow from 192.168.1.0/24 to any port 8775 proto tcp`.
</div>

<div class="callout warning" markdown="1">
Die Router-Tools brauchen einen ASUS-Router mit Qualcomm-WLAN (`wlanconfig`, `apstats`) und SSH mit Schlüssel-Login.
Broadcom-Router haben andere Befehle.
</div>

## Siehe auch

- [[Omarchy]], [[Netzwerktechnik]]
- [[WLAN-Antennen ausrichten]], [[Jitter-Widget]]
