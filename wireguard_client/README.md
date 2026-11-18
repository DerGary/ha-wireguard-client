# WireGuard Client

Hält dieses Home Assistant ständig per VPN mit einem WireGuard-Server verbunden.
So bleibt Home Assistant von unterwegs erreichbar, ohne dass am Router Ports
geöffnet werden müssen.

## Was macht die App?

- Baut beim Start einen verschlüsselten Tunnel zum Server auf.
- Startet bei jedem Neustart von selbst, schon bevor Home Assistant hochgefahren ist.
- Fällt die Internetverbindung oder der Server aus, versucht sie es von selbst
  weiter, bis die Verbindung wieder steht. Ein Eingreifen ist nicht nötig.
- Hängt die App selbst, startet Home Assistant sie automatisch neu.

## Läuft alles?

Oben auf dieser Seite auf **Web-UI öffnen** klicken:

| Anzeige | Bedeutung |
| --- | --- |
| **Verbunden** (grün) | Alles in Ordnung. |
| **Nicht verbunden** (rot) | Kein Kontakt zum Server. Meist ist das Internet kurz weg, die App verbindet sich danach von selbst wieder. Bleibt es länger rot, Bescheid geben, wer das VPN betreut. |

Wer die Anzeige öfter braucht, schaltet unter **Info** den Schalter
**In Seitenleiste anzeigen** ein.

Für Automationen gibt es außerdem den Sensor `binary_sensor.wireguard_client`
(`on` = verbunden), z. B. für eine Benachrichtigung bei Ausfall.

## Einrichtung

Siehe Reiter **Dokumentation**.
