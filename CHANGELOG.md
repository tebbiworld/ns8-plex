# Changelog

## 1.0.1 — 2026-09-13

### Fixed

- **The NS8 backup did not include the Plex database.** Without a
  `state-include.conf` the core backs up `state/environment` only; the
  `state-exclude.conf` shipped in 1.0.0 had nothing to act on. The backup now
  includes the module state and the `plex-config` volume (database, metadata,
  thumbnails), still without `Cache`, `Logs` and `Crash Reports`.

## 1.0.0 — 2026-09-12

- Initial release: Plex Media Server from the official `plexinc/pms-docker`
  image (pinned version), Traefik route or host network mode, read-only media
  paths from node mounts (iSCSI/NFS) with a pre-start mount guard, one-time
  claim token, optional `/dev/dri` pass-through, backup excludes.
