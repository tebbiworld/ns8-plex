# Changelog

## 1.1.0 — 2026-09-19

Alignment with the NethServer module conventions (NethServer/agents skills).

### Changed

- **Working restore.** New `restore-module` steps re-apply every setting on the restored instance (host name and route, network mode, media folders, hardware transcoding, time zone); the server keeps its identity and stays claimed. Media folders that do not exist on the restore node are reported instead of aborting the restore.
- `update-module` only restarts a running instance.

### Added

- Robot Framework tests (install, update from the previous release, backup and restore with an identity check) run on real NS8 nodes through `stephdl/ns8-ci-actions`.

Secrets: nothing to move. The one-time claim token only ever lived in `state/plex.env`, never in the module environment.

### Platform integration

- **Clone and move.** New `clone-module` step (a link to the restore step): a cloned or moved instance gets its route and settings back instead of coming up unconfigured. The settings are read from the source instance, including those a new instance starts with a default for.
- `org.nethserver.volumes`: the bulk-data volume(s) `plex-config plex-transcode` can be placed on an additional disk when the module is installed.
- The software centre shows the upstream terms before installation (`terms_url`); release notes are linked (`relnotes_url`).

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
