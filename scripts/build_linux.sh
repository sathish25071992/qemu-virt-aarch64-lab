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

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

# Configure once (out-of-tree)
if [[ ! -f "${LINUX_BUILD}/.config" ]]; then
  log "Configuring Linux (out-of-tree)..."
  make -C "${LINUX_SRC}" O="${LINUX_BUILD}" defconfig

  # Start from your baseline
  cp -f "${ROOT_DIR}/configs/linux/defconfig" "${LINUX_BUILD}/.config"

  # Ensure required options (scripts/config lives in source tree)
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

  make -C "${LINUX_SRC}" O="${LINUX_BUILD}" olddefconfig
fi

log "Building Linux Image (out-of-tree)..."
make -C "${LINUX_SRC}" O="${LINUX_BUILD}" -j"$(nproc)" Image

VMLINUX="${LINUX_BUILD}/arch/arm64/boot/Image"
if [[ ! -f "${VMLINUX}" ]]; then
  echo "ERROR: Kernel Image not found at: ${VMLINUX}" >&2
  echo "Listing possible Image locations:" >&2
  find "${OUT_DIR}" -type f -name Image -maxdepth 8 -print >&2 || true
  exit 1
fi

cp -f "${VMLINUX}" "${IMG_DIR}/Image"
log "Linux Image -> ${IMG_DIR}/Image"
