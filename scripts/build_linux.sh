#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_cmd git
require_cmd make
require_cmd aarch64-linux-gnu-gcc

LINUX_REPO="$(yver linux repo)"
LINUX_REF="$(yver linux ref)"

LINUX_SRC="${SRC_DIR}/linux"
LINUX_BUILD="${BUILD_DIR}/linux"

log "Linux repo: ${LINUX_REPO} ref: ${LINUX_REF}"
git_checkout_ref "${LINUX_SRC}" "${LINUX_REPO}" "${LINUX_REF}"

mkdir -p "${LINUX_BUILD}"
pushd "${LINUX_SRC}" >/dev/null

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export O="${LINUX_BUILD}"

if [[ ! -f "${LINUX_BUILD}/.config" ]]; then
  log "Configuring Linux..."
  make defconfig
  # Merge our baseline config (simple override approach)
  cp -f "${ROOT_DIR}/configs/linux/defconfig" "${LINUX_BUILD}/.config"

  # Ensure must-have options (non-interactive)
  "${LINUX_SRC}/scripts/config" --file "${LINUX_BUILD}/.config" \
    -e CONFIG_SERIAL_AMBA_PL011 \
    -e CONFIG_SERIAL_AMBA_PL011_CONSOLE \
    -e CONFIG_VIRTIO \
    -e CONFIG_VIRTIO_MMIO \
    -e CONFIG_DEVTMPFS \
    -e CONFIG_DEVTMPFS_MOUNT \
    -e CONFIG_BLK_DEV_INITRD \
    -e CONFIG_TMPFS \
    -e CONFIG_ARCH_VIRT \
    -e CONFIG_EFI \
    -e CONFIG_EFI_STUB \
    -d CONFIG_DEBUG_INFO || true

  make olddefconfig
fi

log "Building Linux Image..."
make -j"$(nproc)" Image

VMLINUX="${LINUX_BUILD}/arch/arm64/boot/Image"
cp -f "${VMLINUX}" "${IMG_DIR}/Image"
log "Linux Image -> ${IMG_DIR}/Image"

popd >/dev/null
