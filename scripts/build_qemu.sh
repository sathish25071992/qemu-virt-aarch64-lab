#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_cmd git
require_cmd ninja
require_cmd python3

QEMU_REPO="$(yver qemu repo)"
QEMU_REF="$(yver qemu ref)"

QEMU_SRC="${SRC_DIR}/qemu"
QEMU_BUILD="${BUILD_DIR}/qemu"

log "QEMU repo: ${QEMU_REPO} ref: ${QEMU_REF}"
git_checkout_ref "${QEMU_SRC}" "${QEMU_REPO}" "${QEMU_REF}"

mkdir -p "${QEMU_BUILD}"
pushd "${QEMU_BUILD}" >/dev/null

if [[ ! -f "build.ninja" ]]; then
  log "Configuring QEMU..."
  "${QEMU_SRC}/configure" \
    --target-list=aarch64-softmmu \
    --enable-slirp \
    --disable-werror
fi

log "Building QEMU..."
ninja -j"$(nproc)"

log "QEMU built: ${QEMU_BUILD}/qemu-system-aarch64"
popd >/dev/null
