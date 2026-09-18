<!--
First community post for the NS8 Plex module, written in the style
of https://community.nethserver.org/t/ns8-forgejo-testing/28554 (first post).
Paste into a new topic on community.nethserver.org, category "App", tag "ns8".
Fill in the wiki link once the page is published.
-->

# NS8 Plex (testing)

Hi all,

I've built an NS8 module for [Plex Media Server](https://www.plex.tv/media-server-downloads/) — it organises your own movies, series, music and photos and streams them to the Plex apps on phones, TVs, browsers and set-top boxes, at home and away.

It's in my community repository. To try it, add the repo once:

```
api-cli run add-repository --data '{"name":"tebbiworld","url":"https://raw.githubusercontent.com/tebbiworld/ns8-repo/main/ns8/updates/","status":true,"testing":false}'
```

then install **Plex** from the Software Center. (Or straight from the image: `add-module ghcr.io/tebbiworld/plex:latest 1`.)

What it does:

* Runs the official `plexinc/pms-docker` image on a NethServer 8 node — the module ships no Plex software of its own, the node pulls the pinned image at install and update time.
* Serves media from storage the **node** mounts (an iSCSI disk, NFS shares from a NAS or from the Samba file server), passed read-only into the container at the **same** path, so an existing library migrates without a re-scan.
* Bridge mode by default (one Traefik host name with Let's Encrypt and HTTP→HTTPS), or host networking so LAN clients discover the server automatically via GDM/DLNA.
* A pre-start guard refuses to run Plex while a media mount is missing, so a library is never emptied by a scan against an empty directory.
* One-time claim token to link the server to your Plex account, and optional `/dev/dri` pass-through for hardware transcoding.
* Backs up the Plex database and metadata through the NS8 backup.

A few things to know:

* A Plex account is required to link ("claim") the server; hardware transcoding additionally needs Plex Pass.
* NS8 nodes run SELinux in enforcing mode, so media mounts need a `context=` mount option, and because the container is rootless the files must be world-readable (`chmod -R o+rX`). The README walks through iSCSI, NFS and Samba-share cases.
* Keep the same absolute paths as on your old host when migrating — Plex stores them in its database.
* Only one host-mode instance per node (port 32400). The media itself is external storage and is not part of the module backup — back it up where it lives.

I'd love a few brave testers: if you point it at your library and something misbehaves, tell me what and I'll dig in.

Docs: NethServer wiki (tebbiworld repository) · Source: [github.com/tebbiworld/ns8-plex](https://github.com/tebbiworld/ns8-plex)

Thanks!

*Category: App · Tags: ns8*
