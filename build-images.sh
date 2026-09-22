#!/bin/bash

#
# Copyright (C) 2026 tebbi
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e

images=()
repobase="${REPOBASE:-ghcr.io/tebbiworld}"
reponame="plex"

# Runtime image pinned by the module through the org.nethserver.images label so
# the node pre-pulls it and exposes its reference to the systemd unit as
# ${PMS_DOCKER_IMAGE} (image basename, uppercased, non-alphanumerics -> "_").
#
# This is the official Plex image. It ships the Plex Media Server binary of
# exactly this version (the "public"/"beta" tags would self-update at every
# start and are deliberately not used). Bump the tag to ship a new Plex
# version through the Software Center.
pms_image="docker.io/plexinc/pms-docker:1.43.4.10903-e5521bd8c"

runtime_images=(
    "${pms_image}"
)

container=$(buildah from scratch)

# Reuse an existing nodebuilder container to speed up UI rebuilds
if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-plex; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-plex -v "${PWD}:/usr/src:Z" docker.io/library/node:24.16.0-slim
fi

echo "Build static UI files with node..."
buildah run \
    --workingdir=/usr/src/ui \
    --env="NODE_OPTIONS=--openssl-legacy-provider" \
    nodebuilder-plex \
    sh -c "yarn install && yarn build"

buildah add "${container}" imageroot /imageroot
buildah add "${container}" ui/dist /ui
# One TCP port: the Plex web/API port published on the node loopback (bridge
# mode), fronted by Traefik. Host network mode uses 32400 directly instead.
# The bulk-data volumes can be placed on an additional disk at install time.
buildah config --entrypoint=/ \
    --label="org.nethserver.authorizations=traefik@node:routeadm" \
    --label="org.nethserver.tcp-ports-demand=1" \
    --label="org.nethserver.rootfull=0" \
    --label="org.nethserver.images=${runtime_images[*]}" \
    --label="org.nethserver.volumes=plex-config plex-transcode" \
    "${container}"
buildah commit "${container}" "${repobase}/${reponame}"

images+=("${repobase}/${reponame}")

if [[ -n "${CI}" ]]; then
    printf "images=%s\n" "${images[*],,}" >> "${GITHUB_OUTPUT}"
else
    printf "Publish the images with:\n\n"
    for image in "${images[@],,}"; do printf "  buildah push %s docker://%s:%s\n" "${image}" "${image}" "${IMAGETAG:-latest}" ; done
    printf "\n"
fi
