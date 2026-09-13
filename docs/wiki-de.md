# Plex Media Server (ns8-plex)

Plex Media Server als NethServer-8-Modul. Das Modul ist ein dünner Wrapper um das
offizielle Image `docker.io/plexinc/pms-docker` (Version im Modul fest verdrahtet,
neue Plex-Version = neues Modul-Release im Software Center). Die Medien liegen auf
Speicher, den der **Knoten** einbindet (iSCSI-Platte, NFS-Freigaben) und werden
schreibgeschützt in den Container durchgereicht.

- Quelle: <https://github.com/tebbiworld/ns8-plex> · Image: `ghcr.io/tebbiworld/plex`
- Katalog: Repository `tebbiworld` im Software Center, Kategorie *Media*
- Voraussetzung: Plex-Konto (zum Verknüpfen des Servers); Hardware-Transcoding zusätzlich Plex Pass

## Aufbau

| Bestandteil | Was |
|---|---|
| Container `plex` | ein rootless Container, Port 32400 |
| Volume `plex-config` | Datenbank, Metadaten, Vorschaubilder → im NS8-Backup (ohne Cache/Logs) |
| Volume `plex-transcode` | Zwischenspeicher des Transcoders → nicht im Backup |
| Medienpfade | Host-Pfade, read-only unter **demselben Pfad** im Container → nicht im Backup |

Zwei Netzwerkmodi (Einstellung *Netzwerkmodus*):

- **Bridge** (Standard): nur der Web-/API-Port wird auf `127.0.0.1` veröffentlicht, Traefik stellt ihn unter dem Hostnamen mit TLS bereit. Clients finden den Server über plex.tv und die automatisch gesetzte Zugriffs-URL `https://<host>:443`.
- **Host**: Plex belegt 32400 und die Discovery-Ports (GDM 32410–32414/udp, DLNA 1900/udp, 32469) direkt auf der Knoten-IP — Clients im LAN finden den Server von selbst. Nur eine solche Instanz pro Knoten.

## Installation

Software Center → Plex Media Server → Installieren, oder:

```
add-module ghcr.io/tebbiworld/plex:latest 1
```

Danach auf der Einstellungsseite: Hostname (FQDN, muss auf den Knoten zeigen), Let's Encrypt, HTTP→HTTPS, Zeitzone. Speichern — der Container startet, ist aber noch ohne Bibliotheken und ohne Konto.

## Speicher auf dem Knoten vorbereiten

Der Container kann weder iSCSI noch NFS selbst mounten. Der Knoten übernimmt diese Rolle, wie es vorher ein normaler Linux-Plex-Host getan hat. Drei Punkte sind zwingend:

### 1. Mount mit SELinux-Kontext

NS8-Knoten laufen mit SELinux *enforcing*. Ein normal gemountetes Verzeichnis ist `unlabeled_t`, und der Container darf darauf **nichts** lesen — auch keine world-readable Datei. Die Mount-Option `context=` löst das, ohne eine einzige Datei umzulabeln:

```
# /etc/fstab
UUID=<uuid>  /media/plex   ext4  _netdev,nofail,errors=remount-ro,context="system_u:object_r:container_file_t:s0"  0 0
nas:/export/musik  /media/musik  nfs  ro,_netdev,nofail,x-systemd.automount,context="system_u:object_r:container_file_t:s0"  0 0
```

Für iSCSI vorher einmalig:

```
dnf install -y iscsi-initiator-utils
iscsiadm -m discovery -t st -p <Portal-IP>
iscsiadm -m node -T <IQN> -p <Portal-IP> -o update -n node.startup -v automatic
systemctl enable --now iscsid
```

`_netdev` und `nofail`, weil Gerät bzw. Server erst nach dem Netz da sind — fehlt der Mount, blockiert nicht der Boot, sondern nur der Start von Plex (siehe Guard).

### 2. Leserechte

Der Container ist rootless: Dateien fremder Eigentümer erscheinen darin als `nobody`. Plex liest daher nur Dateien mit gesetztem *other-read*-Bit.

- **Lokale Platte (iSCSI):** einmalig `chmod -R o+rX /media/plex`.
- **NFS mit `all_squash,anonuid=…`:** nichts zu tun — der NFS-Server prüft jeden Zugriff serverseitig als der eingestellte Benutzer, die Rechte-Bits sind egal. (So ist die Freigabe vom Samba-Knoten eingerichtet.)
- **NFS nur mit `root_squash`:** Rechte-Bits gelten wie bei der lokalen Platte.

### 3. Gleiche Pfade wie zuvor

Plex speichert absolute Pfade in seiner Datenbank. Wer eine bestehende Bibliothek übernimmt, mountet die Medien unter **demselben** Pfad wie auf dem alten Host (z. B. `/media/plex`, `/media/musik`, `/media/foto`).

## Einstellungen

| Feld | Bedeutung |
|---|---|
| Medienpfade | ein absoluter Pfad pro Zeile; keine Leerzeichen, Kommas, Doppelpunkte |
| Gemountetes Dateisystem erforderlich | Start-Guard: jeder Pfad muss existieren, für den Modul-Benutzer lesbar sein und auf einem gemounteten Dateisystem (nicht `/`) liegen. Schützt davor, dass Plex nach einem Reboot ohne Mount ein leeres Verzeichnis scannt und die Bibliothek leert. Nur abschalten, wenn Medien auf der Systemplatte liegen. |
| Claim-Token | Einmal-Token von <https://www.plex.tv/claim>, 4 Minuten gültig. Verknüpft den Server beim nächsten Start mit dem Plex-Konto. Ohne Token funktioniert der Einrichtungsassistent nur von `localhost` aus. Wird nicht gespeichert; die Seite zeigt, ob der Server verknüpft ist. |
| Hardware-Transcoding | reicht `/dev/dri` durch. Vorher auf dem Knoten `usermod -aG render,video <modul-user>` (z. B. `plex1`). Plex Pass nötig. |

Nach dem Verknüpfen in Plex prüfen: *Einstellungen → Netzwerk → Benutzerdefinierte Serverzugriffs-URLs* enthält `https://<host>:443` (setzt das Modul), *Sichere Verbindungen: Bevorzugt*. Dann Bibliotheken auf die Medienpfade anlegen.

## Bestehenden Plex-Server umziehen

1. Modul installieren und Hostname konfigurieren — noch ohne Medienpfade, noch nicht verknüpfen.
2. Alten Server stoppen. iSCSI: LUN dort abmelden (`iscsiadm -m node -u`) — eine LUN verträgt nur einen Initiator. Auf dem Knoten anmelden, fstab, `mount -a`, Rechte prüfen.
3. Datenbank übernehmen (Linux-Paket: `/var/lib/plexmediaserver/Library/Application Support/Plex Media Server`):

   ```
   runagent -m plex1 podman volume inspect plex-config --format '{{.Mountpoint}}'
   systemctl --user -M plex1@ stop plex.service
   rsync -a "alt:/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/" \
         "/home/plex1/.local/share/containers/storage/volumes/plex-config/_data/Library/Application Support/Plex Media Server/"
   chown -R plex1:plex1 /home/plex1/.local/share/containers/storage/volumes/plex-config/_data
   systemctl --user -M plex1@ start plex.service
   ```

   Serveridentität, Konto-Verknüpfung und Bibliotheken wandern mit — kein Claim-Token nötig.
4. Medienpfade eintragen, speichern. Die Bibliotheken zeigen sofort Inhalt.
5. Zugriffs-URL in Plex prüfen (siehe oben).

## Backup und Update

- NS8-Backup: State + `plex-config` (ohne `Cache`, `Logs`, `Crash Reports`); `plex-transcode` und die Medien sind ausgenommen. Medien dort sichern, wo sie liegen.
- Modul-Update startet den Dienst automatisch neu; die neue Plex-Version läuft sofort.

## Fehlersuche

| Symptom | Ursache / Abhilfe |
|---|---|
| Dienst startet nicht, Journal: `plex-check-media: … is not on a mounted filesystem` | Mount fehlt (nach Reboot, iSCSI/NFS nicht erreichbar). Mounten, dann `systemctl --user -M plex1@ restart plex.service`. |
| `… is not readable by plex1` | Rechte: `chmod -R o+rX <pfad>` bzw. NFS-Exportoptionen. |
| Bibliothek leer, obwohl Dateien da | SELinux-Kontext fehlt (`context=` in der fstab), oder Pfad im Container weicht vom Pfad in der Bibliothek ab. |
| „Bad Gateway" unter dem Hostnamen | Container startet noch (erster Start ~30 s) — `runagent -m plex1 podman logs plex`. |
| Server nicht verknüpfbar | Token älter als 4 Minuten — neuen Token holen und sofort speichern. |
| LAN-Clients streamen über Relay | Bridge-Modus ohne Discovery. Entweder Zugriffs-URL in den Clients eintragen oder auf Host-Modus umstellen. |

Nützliche Befehle:

```
runagent -m plex1 podman logs plex                 # Plex-Log
runagent -m plex1 systemctl --user status plex     # Dienststatus
journalctl --user -M plex1@ -u plex.service        # Start-Guard-Meldungen
api-cli run module/plex1/get-configuration --data null
```

## Hinweise

- Das Modul verteilt keine Plex-Software; das Image stammt von Plex, Inc. und wird beim Installieren vom Knoten geladen.
- Plex ist eine Marke von Plex, Inc. Dieses Modul ist eine unabhängige Paketierung.
