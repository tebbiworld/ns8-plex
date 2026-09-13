# ns8-plex

A [NethServer 8](https://github.com/NethServer/ns8-core) module that runs
[Plex Media Server](https://www.plex.tv/media-server-downloads/) from the
official `plexinc/pms-docker` image. Media libraries live on storage mounted by
the node (iSCSI disk, NFS shares, ...) and are passed read-only into the
container.

The module ships **no Plex software**: it is a thin wrapper around the image
published by Plex on Docker Hub, pulled by the node at install/update time.
A Plex account is required to link ("claim") the server; hardware transcoding
additionally needs Plex Pass.

## Architecture

One rootless container:

| Container | Image | Port | Exposure |
| --- | --- | --- | --- |
| `plex` | `docker.io/plexinc/pms-docker:<pinned version>` | 32400 | bridge mode: node loopback port fronted by Traefik; host mode: node IP |

| Volume | Mount | Purpose |
| --- | --- | --- |
| `plex-config` | `/config` | database, metadata, thumbnails (in the backup; `Cache`, `Logs` excluded) |
| `plex-transcode` | `/transcode` | transcoder scratch space (excluded from backup) |
| host paths | same path, read-only | the media libraries (not in the backup — back up the storage itself) |

The Plex version is pinned in `build-images.sh`; a new module release through
the Software Center brings a new Plex version. The self-updating `public`/`beta`
image tags are deliberately not used.

## Install

```
add-module ghcr.io/tebbiworld/plex:latest 1
```

## Settings

| Setting | Notes |
| --- | --- |
| Host name | FQDN Plex is published on (Traefik route, Let's Encrypt, HTTP→HTTPS). Also set as Plex *custom server access URL* (`ADVERTISE_IP`) so clients connect through the reverse proxy. |
| Network mode | **Bridge** (default): only `127.0.0.1:<port>` → 32400 is published, everything goes through Traefik. **Host**: `--network=host`, Plex binds 32400 and the GDM (32410–32414/udp) / DLNA (1900/udp, 32469) discovery ports on the node IP — LAN clients discover the server automatically. Only one host-mode instance per node. |
| Media paths | Absolute node paths, one per line. Each is bind-mounted read-only at the *same* path in the container. |
| Require mounted filesystem | Pre-start guard (`bin/plex-check-media`): every media path must exist, be readable by the module user and be on a mounted filesystem other than `/`. Plex would otherwise scan an empty directory and drop the library items. Disable only for media on the system disk. |
| Claim token | One-time token from <https://www.plex.tv/claim> (valid 4 minutes). Links the server to your Plex account at the next start; without it the setup wizard only works from `localhost`. Not stored after use; the page shows whether the server is linked. |
| Hardware transcoding | Passes `/dev/dri` into the container (Intel Quick Sync / AMD). Requires Plex Pass and the module user in the `render`/`video` group (see below). |
| Timezone | `TZ` for the container. |

## Preparing the media storage on the node

The container cannot mount iSCSI or NFS itself; the **node** does, exactly like
a plain Linux Plex host would. Three things matter:

### 1. Mount it — with an SELinux context

```
dnf install -y iscsi-initiator-utils        # iSCSI only
iscsiadm -m discovery -t st -p <target-ip>
iscsiadm -m node -T <iqn> -p <target-ip> --login
systemctl enable --now iscsid
```

`/etc/fstab` (SELinux is enforcing on NS8 nodes; a plain mount is `unlabeled_t`
and the container is denied every read, even of world-readable files):

```
UUID=<uuid>  /mnt/media  xfs  _netdev,nofail,ro,context="system_u:object_r:container_file_t:s0"  0 0
nas:/export/music  /srv/nfs/music  nfs  _netdev,nofail,ro,context="system_u:object_r:container_file_t:s0"  0 0
```

The `context=` option labels the whole mount without touching a single file
(unlike `chcon -R`, which does not work on NFS and would relabel terabytes).
NFS also works through the `virt_use_nfs` boolean, which is on by default.

### 2. Make the files world-readable

The container is rootless: files owned by any user other than the module user
appear as `nobody` inside it. Plex therefore only sees files with the *other*
read bit set:

```
chmod -R o+rX /mnt/media
```

For NFS exports with `root_squash` the same rule applies on the server side, or
export with `all_squash,anonuid=<uid>` matching a readable owner. Read-only is
all Plex needs; the mount is read-only anyway.

### 3. Keep the same paths when migrating

Plex stores absolute paths in its database. Mount the storage at the same path
as on the previous host (e.g. `/mnt/media` on both) and the migrated library
keeps working without re-scanning.

## Migrating an existing Plex server

1. Stop Plex on the old host. For iSCSI: log the LUN out there — a LUN can only
   be attached to one initiator.
2. Mount the storage on the node (above) and configure the module with the same
   media paths.
3. Copy the old `Plex Media Server` directory (Linux packages:
   `/var/lib/plexmediaserver/Library/Application Support/Plex Media Server`)
   into the `plex-config` volume:

   ```
   runagent -m plex1 podman volume inspect plex-config --format '{{.Mountpoint}}'
   # -> /home/plex1/.local/share/containers/storage/volumes/plex-config/_data
   systemctl --user -M plex1@ stop plex.service
   rsync -a "old:/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/" \
         "/home/plex1/.local/share/containers/storage/volumes/plex-config/_data/Library/Application Support/Plex Media Server/"
   chown -R plex1:plex1 /home/plex1/.local/share/containers/storage/volumes/plex-config/_data
   systemctl --user -M plex1@ start plex.service
   ```

   The image chowns `/config` to its `plex` user on start
   (`CHANGE_CONFIG_DIR_OWNERSHIP=true`). Server identity and the Plex account
   link are part of that directory, so no new claim token is needed.
4. Open Plex → Settings → Network and verify *Custom server access URLs*
   contains `https://<host>:443` and *Secure connections* is *Preferred*.

## Hardware transcoding

Rootless containers can only use devices the module user may open. Once, as
root on the node:

```
usermod -aG render,video plex1
```

then enable *Hardware transcoding* in the settings and restart. The dev
virtual machine of this project has no GPU; this path is untested there.

## Backup

The NS8 backup includes the module state and the `plex-config` volume
(`imageroot/etc/state-include.conf`), minus `Cache`, `Logs` and `Crash Reports`
(`state-exclude.conf`); `plex-transcode` is not included. Plex writes its own
database snapshots (`Plug-in Support/Databases/*.db-<date>`) into that volume,
so a restore has a consistent copy even if the live SQLite file was busy. The
media itself is not part of the module backup — it is external storage; back
it up where it lives.

## Notes

* `update-module` restarts the service (`update-module.d/90restart_services`),
  so a new pinned Plex version is running right after the update.
* `runagent -m plex1 podman logs plex` shows the Plex start-up log; the first
  start of a fresh instance creates the database and takes ~30 s.
* Only one instance can use host network mode per node (port 32400).
* Trademarks: Plex is a trademark of Plex, Inc. This module is an independent
  packaging and is not affiliated with or endorsed by Plex, Inc.
