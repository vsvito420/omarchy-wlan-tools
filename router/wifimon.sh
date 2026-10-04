#!/bin/sh
# wifimon – Live-Signalmonitor fuer einen WLAN-Client (ASUS / Qualcomm-Treiber)
# Aufruf: sh /jffs/wifimon.sh MAC [Intervall-Sekunden]
[ -n "$1" ] || { echo "Aufruf: sh wifimon.sh MAC [Intervall]"; exit 1; }
MAC=$(echo "$1" | tr 'A-F' 'a-f')
INT=${2:-1}
STATE=/tmp/wifimon.$$.state
VAP=""

cleanup() { rm -f "$STATE"; printf '\033[?25h\n'; exit 0; }
trap cleanup INT TERM HUP
printf '\033[?25l\033[2J'

find_vap() {
	for d in /sys/class/net/ath*; do
		i=${d##*/}
		wlanconfig "$i" list sta 2>/dev/null | grep -qi "^$MAC" && { echo "$i"; return; }
	done
}

while :; do
	if [ -z "$VAP" ] || ! wlanconfig "$VAP" list sta 2>/dev/null | grep -qi "^$MAC"; then
		VAP=$(find_vap)
	fi
	if [ -z "$VAP" ]; then
		printf '\033[H\033[J  wifimon  –  %s\n\n  Client %s ist gerade in keinem WLAN verbunden. Suche weiter ...\n' "$(date '+%H:%M:%S')" "$MAC"
		sleep "$INT"; continue
	fi
	RADIO=wifi$(echo "$VAP" | cut -c4)
	{
		echo "@@STA"; wlanconfig "$VAP" list sta -v 2>/dev/null
		echo "@@APS"; apstats -s -m "$MAC" 2>/dev/null
		echo "@@IWC"; iwconfig "$VAP" 2>/dev/null
		echo "@@SUR"; iw dev "$VAP" survey dump 2>/dev/null | grep -A1 'in use'
		echo "@@MISC"
		echo "chutil $(cfg80211tool "$VAP" get_chutil 2>/dev/null | sed 's/.*://')"
		echo "apmode $(cfg80211tool "$VAP" get_mode 2>/dev/null | sed 's/.*://')"
		echo "temp $(thermaltool -i "$RADIO" -get 2>/dev/null | sed -n 's/.*sensor temperature: *\([0-9-]*\).*/\1/p')"
		echo "lease $(grep -i " $MAC " /var/lib/misc/dnsmasq.leases 2>/dev/null | head -1)"
		echo "now $(date +%s)"; echo "clock $(date +%H:%M:%S)"
	} | awk -v mac="$MAC" -v vap="$VAP" -v radio="$RADIO" -v ivl="$INT" -v statef="$STATE" '
	function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
	function val(k) { return (k in A) ? A[k] + 0 : 0 }
	function bar(v, lo, hi, w,   n, s, i) {
		n = int((v - lo) / (hi - lo) * w + 0.5); if (n < 0) n = 0; if (n > w) n = w
		s = ""; for (i = 0; i < n; i++) s = s "█"; for (; i < w; i++) s = s "░"; return s
	}
	function col(v, g, y) { return v >= g ? GRN : (v >= y ? YEL : RED) }
	function spark(list, lo, hi,   n, a, i, k, s) {
		n = split(list, a, " "); s = ""
		for (i = 1; i <= n; i++) {
			k = int((a[i] - lo) / (hi - lo) * 7 + 0.5); if (k < 0) k = 0; if (k > 7) k = 7
			s = s SP[k]
		}
		return s
	}
	function push(list, v,   n, a, i, s) {
		n = split(list, a, " "); s = ""
		for (i = (n >= 60 ? n - 58 : 1); i <= n; i++) s = s a[i] " "
		return s v
	}
	function lmax(list,   n, a, i, m) { n = split(list, a, " "); m = 0.1; for (i = 1; i <= n; i++) if (a[i] + 0 > m) m = a[i] + 0; return m }
	function mbit(bytes) { return bytes * 8 / 1e6 }
	function human(b) {
		if (b >= 1e9) return sprintf("%.2f GB", b / 1e9)
		if (b >= 1e6) return sprintf("%.1f MB", b / 1e6)
		return sprintf("%.0f kB", b / 1e3)
	}
	function rating(r) {
		if (r >= -50) return GRN "hervorragend"
		if (r >= -60) return GRN "sehr gut"
		if (r >= -67) return GRN "gut"
		if (r >= -72) return YEL "ok"
		if (r >= -80) return YEL "schwach"
		return RED "schlecht"
	}
	function mcsname(m) {
		return m <= 1 ? "BPSK/QPSK" : m <= 2 ? "QPSK" : m <= 4 ? "16-QAM" : m <= 7 ? "64-QAM" : m <= 9 ? "256-QAM" : m <= 11 ? "1024-QAM" : "4096-QAM"
	}
	# MCS-Verteilung (Delta seit letztem Sample, sonst kumulativ)
	function mcsline(dir,   i, k, tot, s, cur, best, bestv, d, c, n) {
		tot = 0; best = -1; bestv = -1
		for (i = 0; i <= 13; i++) {
			k = dir i; c = (k in MC) ? MC[k] : 0
			d = (k in P) ? c - P[k] : 0; if (d < 0) d = 0
			D[i] = d; C[i] = c; tot += d
		}
		src = "letzte " ivl "s"
		if (tot < 20) { tot = 0; for (i = 0; i <= 13; i++) { D[i] = C[i]; tot += C[i] }; src = "seit Verbindung" }
		s = ""
		for (i = 0; i <= 13; i++) {
			if (tot > 0 && D[i] / tot >= 0.02) {
				n = int(D[i] / tot * 100 + 0.5)
				s = s sprintf("%s%d%s:%d%% ", BLD, i, RST, n)
			}
			if (D[i] > bestv) { bestv = D[i]; best = i }
		}
		DOM[dir] = best
		return (s == "" ? "–" : s) DIM "(" src ")" RST
	}
	BEGIN {
		ESC = sprintf("%c", 27)
		RST = ESC "[0m"; BLD = ESC "[1m"; DIM = ESC "[2m"
		RED = ESC "[31m"; GRN = ESC "[32m"; YEL = ESC "[33m"; CYN = ESC "[36m"; MAG = ESC "[35m"
		split("▁ ▂ ▃ ▄ ▅ ▆ ▇ █", tmp, " "); for (i = 1; i <= 8; i++) SP[i - 1] = tmp[i]
		while ((getline line < statef) > 0) { p = index(line, "="); P[substr(line, 1, p - 1)] = substr(line, p + 1) }
		close(statef)
	}
	/^@@/ { sec = substr($0, 3); next }
	sec == "STA" && $1 ~ /^[0-9a-fA-F][0-9a-fA-F]:/ { me = (tolower($1) == mac) }
	sec == "STA" && !me { next }
	sec == "STA" && tolower($1) == mac {
		nsta++; rssi = $6; rmin = $7; rmax = $8; idle = $9
		for (i = 12; i <= NF; i++) if (maxrate == "" && $i ~ /^[0-9][0-9][0-9][0-9][0-9]+$/) maxrate = $i
		for (i = 17; i <= NF; i++) {
			if ($i ~ /^[0-9]+:[0-9]+:[0-9]+$/) assoc = $i
			if ($i ~ /^IEEE80211_MODE_/) { mode = substr($i, 16); rxnss = $(i + 1); txnss = $(i + 2); psm = $(i + 3) }
			if ($i == "RSN" || $i == "WME" || $i == "WPA") ies = ies $i " "
		}
		next
	}
	sec == "STA" && /SNR/ { split($0, t, ":"); snr = trim(t[2]) + 0; next }
	sec == "STA" && /Maximum Tx Power/ { split($0, t, ":"); stamaxpwr = trim(t[2]); next }
	sec == "STA" && /MU capable/ { split($0, t, ":"); mucap = trim(t[2]); next }
	sec == "STA" && /^ MLO/ { split($0, t, ":"); mlo = trim(t[2]); next }
	sec == "STA" && /Current Operating class/ { split($0, t, ":"); opcl = trim(t[2]); next }
	sec == "APS" && /^TX MCS Stats/ { mdir = "tx"; next }
	sec == "APS" && /^RX MCS Stats/ { mdir = "rx"; next }
	sec == "APS" && /^(HE|EHT) MCS [0-9]+/ {
		m = $3; split($0, t, ":"); v = trim(t[2]) + 0
		MC[mdir m] += v; if ($1 == "EHT" && v > 0) usedeht = 1; next
	}
	sec == "APS" && /Ack RSSI chain/ {
		match($0, /chain [0-9]+/); ch = substr($0, RSTART + 6, RLENGTH - 6)
		match($0, /RSSI -?[0-9]+/); cr = substr($0, RSTART + 5, RLENGTH - 5)
		match($0, /SNR -?[0-9]+/); cs = substr($0, RSTART + 4, RLENGTH - 4)
		chains = chains sprintf("  Kette %s: %s%4d dBm%s  SNR %2d dB\n", ch, col(cr, -60, -72), cr, RST, cs)
		next
	}
	sec == "APS" && /=/ { p = index($0, "="); A[trim(substr($0, 1, p - 1))] = trim(substr($0, p + 1)); next }
	sec == "IWC" {
		if (match($0, /ESSID:"[^"]*"/)) ssid = substr($0, RSTART + 7, RLENGTH - 8)
		if (match($0, /Frequency:[0-9.]+ GHz/)) freq = substr($0, RSTART + 10, RLENGTH - 14)
		if (match($0, /Tx-Power:[0-9]+ dBm/)) appwr = substr($0, RSTART + 9, RLENGTH - 13)
		if (match($0, /Access Point: [0-9A-Fa-f:]+/)) bssid = substr($0, RSTART + 14, RLENGTH - 14)
		next
	}
	sec == "SUR" && /noise/ { nf = $2; next }
	sec == "MISC" { k = $1; $1 = ""; M[k] = trim($0); next }
	END {
		if (rssi == "") { printf "%s[H%s[J  Keine Daten fuer %s auf %s\n", ESC, ESC, mac, vap; exit }
		split(M["lease"], L, " "); ip = L[3]; host = L[4]
		now = M["now"] + 0
		chan = int((freq * 1000 - (freq < 3 ? 2407 : freq < 5.9 ? 5000 : 5950)) / 5 + 0.5)
		band = freq < 3 ? "2,4 GHz" : freq < 5.9 ? "5 GHz" : "6 GHz"
		bw = val("Band Width")
		noise = (nf != "") ? nf : rssi - snr

		# Deltas seit letztem Sample
		dt = (P["now"] > 0) ? now - P["now"] : 0
		dtried = val("Tx mpdu tried count") - P["tried"]; dsucc = val("Tx mpdu success count") - P["succ"]
		dretr = val("MPDU: Tx total_mpdu_retries") - P["retr"]
		drx = val("Rx mpdu count") - P["rxm"]; drxr = val("Rx retry count") - P["rxr"]
		if (dt <= 0 || dtried < 0) { dtried = val("Tx mpdu tried count"); dsucc = val("Tx mpdu success count"); dretr = val("MPDU: Tx total_mpdu_retries"); drx = val("Rx mpdu count"); drxr = val("Rx retry count"); rsrc = "seit Verbindung" } else rsrc = "letzte " dt "s"
		txretry = dtried > 0 ? dretr / dtried * 100 : 0
		txfail  = dtried > 0 ? (dtried - dsucc) / dtried * 100 : 0
		rxretry = drx > 0 ? drxr / drx * 100 : 0

		txr = val("Last tx rate") / 1000; rxr = val("Last rx rate") / 1000
		txa = val("Average Tx rate (kbps)"); if (txa == 0) txa = val("Average Tx Rate (kbps)"); txa /= 1000
		rxa = val("Average Rx Rate (kbps)") / 1000
		maxr = maxrate / 1000
		txs = mbit(val("Tx bytes for last one second")); rxs = mbit(val("Rx bytes for last one second"))

		HR = push(P["hr"], rssi); HT = push(P["ht"], int(txr)); HX = push(P["hx"], int(rxr))
		HD = push(P["hd"], sprintf("%.1f", rxs)); HU = push(P["hu"], sprintf("%.1f", txs))

		txmcs = mcsline("tx"); rxmcs = mcsline("rx")
		gen = usedeht ? "Wi-Fi 7 (EHT)" : (mode ~ /HE/ ? "Wi-Fi 6/6E (HE)" : (mode ~ /VHT/ ? "Wi-Fi 5 (VHT)" : mode))

		o = ESC "[H" ESC "[J"
		o = o sprintf("%s wifimon %s  %s%s%s  %s   %s%s%s\n", BLD CYN, RST, BLD, (host != "" ? host : "?"), RST, mac, DIM, M["clock"], RST)
		o = o sprintf("  IP %s   verbunden seit %s   Leerlauf %ss   Stromsparmodus %s\n", ip, assoc, idle, (psm ? "an" : "aus"))
		o = o sprintf("%s─── Verbindung ────────────────────────────────────────────────────────%s\n", DIM, RST)
		o = o sprintf("  SSID %s%s%s  (%s)   BSSID %s\n", BLD, ssid, RST, vap, bssid)
		o = o sprintf("  Band %s  Kanal %s (%.3f GHz)  Breite %s MHz   Router kann %s\n", band, chan, freq, bw, M["apmode"])
		o = o sprintf("  Client-Modus %s  %s  %dx%d MIMO  MU-MIMO %s  MLO %s  OpClass %s  %s\n", mode, gen, txnss, rxnss, mucap, mlo, opcl, ies)
		o = o sprintf("  Sendeleistung Router %s dBm   Client max %s dBm   Kanalauslastung %s%%   Radio %s°C\n", appwr, stamaxpwr, M["chutil"], M["temp"])
		o = o sprintf("%s─── Signal ────────────────────────────────────────────────────────────%s\n", DIM, RST)
		o = o sprintf("  RSSI   %s%s%4d dBm%s  %s%s  %s%s\n", BLD, col(rssi, -60, -72), rssi, RST, col(rssi, -60, -72), bar(rssi, -90, -30, 30), rating(rssi), RST)
		o = o sprintf("  SNR    %s%4d dB %s  %s%s%s   Rauschen %s dBm\n", col(snr, 35, 25), snr, RST, col(snr, 35, 25), bar(snr, 0, 60, 30), RST, noise)
		o = o sprintf("  Min/Max seit Verbindung: %d / %d dBm   Mgmt-RSSI %d dB ueber Rauschen\n", rmin, rmax, val("Rx MGMT RSSI"))
		o = o chains
		o = o sprintf("  Verlauf %s%s%s %s(-90..-30 dBm)%s\n", CYN, spark(HR, -90, -30), RST, DIM, RST)
		o = o sprintf("%s─── Datenrate (PHY) ───────────────────────────────────────────────────%s\n", DIM, RST)
		o = o sprintf("  Router→PC  %s%5d Mbit/s%s  Ø %5d   %s%s  %3d%% von %d\n", BLD, txr, RST, txa, GRN, bar(txr, 0, maxr, 20) RST, (maxr > 0 ? txr / maxr * 100 : 0), maxr)
		o = o sprintf("  PC→Router  %s%5d Mbit/s%s  Ø %5d   %s%s  %3d%% von %d\n", BLD, rxr, RST, rxa, MAG, bar(rxr, 0, maxr, 20) RST, (maxr > 0 ? rxr / maxr * 100 : 0), maxr)
		o = o sprintf("  ↓ Verlauf %s%s%s\n  ↑ Verlauf %s%s%s\n", GRN, spark(HT, 0, maxr), RST, MAG, spark(HX, 0, maxr), RST)
		o = o sprintf("  MCS ↓ %s\n", txmcs)
		o = o sprintf("  MCS ↑ %s\n", rxmcs)
		o = o sprintf("  meist genutzt: ↓ MCS %d (%s)   ↑ MCS %d (%s)\n", DOM["tx"], mcsname(DOM["tx"]), DOM["rx"], mcsname(DOM["rx"]), RST)
		o = o sprintf("%s─── Durchsatz (echte Nutzdaten) ───────────────────────────────────────%s\n", DIM, RST)
		o = o sprintf("  ↓ Download %s%8.1f Mbit/s%s  %s  %d Pakete/s\n", BLD, txs, RST, spark(HU, 0, lmax(HU)), val("Tx packets for last one second"))
		o = o sprintf("  ↑ Upload   %s%8.1f Mbit/s%s  %s  %d Pakete/s\n", BLD, rxs, RST, spark(HD, 0, lmax(HD)), val("Rx packets for last one second"))
		o = o sprintf("  Gesamt ↓ %s   ↑ %s\n", human(val("Tx Data Bytes")), human(val("Rx Data Bytes")))
		o = o sprintf("%s─── Qualitaet (%s) ─────────────────────────────────────────%s\n", DIM, rsrc, RST)
		o = o sprintf("  TX-Retries %s%5.1f%%%s   TX verloren %s%5.2f%%%s   RX-Retries %s%5.1f%%%s   PER %s%%\n",
			(txretry < 10 ? GRN : txretry < 25 ? YEL : RED), txretry, RST, (txfail < 1 ? GRN : txfail < 5 ? YEL : RED), txfail, RST,
			(rxretry < 10 ? GRN : rxretry < 25 ? YEL : RED), rxretry, RST, val("Last Packet Error Rate (PER)"))
		o = o sprintf("  Fehler: Entschluesselung %d  MIC %d  PN %d  RX %d  TX failed %d  Discard %d\n",
			val("Rx Decryption errors"), val("Rx MIC Errors"), val("Rx PN errors"), val("Rx errors"), val("Tx failed"), val("Host Discard"))
		o = o sprintf("%s  Strg+C zum Beenden · Intervall %ss%s\n", DIM, ivl, RST)
		printf "%s", o

		printf "now=%s\ntried=%s\nsucc=%s\nretr=%s\nrxm=%s\nrxr=%s\nhr=%s\nht=%s\nhx=%s\nhd=%s\nhu=%s\n", now,
			val("Tx mpdu tried count"), val("Tx mpdu success count"), val("MPDU: Tx total_mpdu_retries"),
			val("Rx mpdu count"), val("Rx retry count"), HR, HT, HX, HD, HU > statef
		for (k in MC) printf "%s=%s\n", k, MC[k] > statef
		close(statef)
	}'
	sleep "$INT"
done
