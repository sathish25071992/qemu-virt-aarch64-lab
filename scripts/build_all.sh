#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

PLATFORM="${PLATFORM:-virt-cortex-a53}"

log "Building for PLATFORM=${PLATFORM}"
# Validate platform exists
_="$(yplat "${PLATFORM}" cpu)"

bash scripts/build_qemu.sh
bash scripts/build_linux.sh
bash scripts/build_busybox_rootfs.sh

log "Build complete."
log "Artifacts:"
log "  QEMU:   ${BUILD_DIR}/qemu/qemu-system-aarch64"
log "  Image:  ${IMG_DIR}/Image"
log "  Rootfs: ${IMG_DIR}/rootfs.cpio.gz"
