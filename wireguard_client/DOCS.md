# WireGuard Client

Verbindet dieses Home Assistant dauerhaft mit einem WireGuard-Server.

## Einrichtung

1. Auf dem Server eine Client-Konfiguration erzeugen (z. B. `peer_xyz.conf`).
2. Hier unter **Konfiguration** die Werte aus dieser Datei eintragen:

   | Feld | aus der .conf |
   | --- | --- |
   | Private Key | `[Interface]` → `PrivateKey` |
   | VPN-Adresse | `[Interface]` → `Address` |
   | Public Key des Servers | `[Peer]` → `PublicKey` |
   | Preshared Key | `[Peer]` → `PresharedKey` (falls vorhanden) |
   | Server-Adresse | `[Peer]` → `Endpoint` |
   | Erlaubte IPs | nur das VPN-Netz, z. B. `172.16.0.0/24` |

   `DNS` aus der .conf wird absichtlich nicht übernommen. VPN-Adresse und
   erlaubte IPs müssen private Netze sein: Mit `0.0.0.0/0` ginge sonst der ganze
   Internetverkehr von Home Assistant über den Server. Eine VPN-Adresse oder
   erlaubte IPs im eigenen Heimnetz lehnt die App ebenfalls ab, weil Home Assistant
   sonst im Heimnetz nicht mehr erreichbar wäre.
3. Speichern und die App starten.

Die App startet danach bei jedem Neustart von selbst. Der Watchdog wird beim
ersten Start automatisch eingeschaltet.

## Läuft es?

- **Web-UI öffnen** auf dieser Seite zeigt groß *Verbunden* (grün) oder
  *Nicht verbunden* (rot). Die Seite aktualisiert sich alle 10 Sekunden.
  Mit „In Seitenleiste anzeigen“ lässt sie sich zusätzlich in die Seitenleiste legen.
- `binary_sensor.wireguard_client` ist `on`, solange der Server antwortet,
  z. B. für eine Benachrichtigung bei Ausfall.
- Im Log steht jede Statusänderung.

„Nicht verbunden“ heißt meist: Internet weg oder Server nicht erreichbar. Die App
versucht es von selbst weiter, ein Neustart ist nicht nötig.

## Technisches

- Interface `hawg0` im Host-Netz, Kernel-WireGuard.
- Verbindung gilt als getrennt, wenn der letzte Handshake älter als 195 Sekunden
  plus Keepalive ist (220 Sekunden bei Keepalive 25).
  Dann wird der Server-Name alle 15 Sekunden neu aufgelöst.
- Verschwindet das Interface, wird der Tunnel neu aufgebaut.
- Docker-Healthcheck schlägt fehl, wenn die Überwachung hängt; der Supervisor startet die App dann neu.
  Ein Server-Ausfall führt absichtlich nicht zu Neustarts.
