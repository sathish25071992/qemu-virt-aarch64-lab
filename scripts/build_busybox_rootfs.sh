#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_cmd git
require_cmd make
require_cmd aarch64-linux-gnu-gcc

BUSYBOX_REPO="$(yver busybox repo)"
BUSYBOX_REF="$(yver busybox ref)"

BUSYBOX_SRC="${SRC_DIR}/busybox"
BUSYBOX_BUILD="${BUILD_DIR}/busybox"
ROOTFS_DIR="${BUILD_DIR}/rootfs"

log "BusyBox repo: ${BUSYBOX_REPO} ref: ${BUSYBOX_REF}"
git_checkout_ref "${BUSYBOX_SRC}" "${BUSYBOX_REPO}" "${BUSYBOX_REF}"

mkdir -p "${BUSYBOX_BUILD}" "${ROOTFS_DIR}"
pushd "${BUSYBOX_SRC}" >/dev/null

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export O="${BUSYBOX_BUILD}"

if [[ ! -f "${BUSYBOX_BUILD}/.config" ]]; then
  log "Configuring BusyBox..."
  make defconfig
  cp -f "${ROOT_DIR}/configs/busybox/defconfig" "${BUSYBOX_BUILD}/.config"
  make olddefconfig
fi

log "Building BusyBox (static)..."
make -j"$(nproc)"
make CONFIG_PREFIX="${ROOTFS_DIR}" install

# Minimal rootfs structure
mkdir -p "${ROOTFS_DIR}/"{proc,sys,dev,etc,tmp,root}

# /init script (runs smoke test + interactive shell)
cat > "${ROOTFS_DIR}/init" <<'SH'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

echo "Booted initramfs."
uname -a || true
echo "Dropping to shell. Type 'poweroff' to exit."

# Keep console usable
exec sh
SH
chmod +x "${ROOTFS_DIR}/init"

# Create initramfs cpio.gz
pushd "${ROOTFS_DIR}" >/dev/null
find . -print0 | cpio --null -ov --format=newc | gzip -9 > "${IMG_DIR}/rootfs.cpio.gz"
popd >/dev/null

log "Initramfs -> ${IMG_DIR}/rootfs.cpio.gz"
popd >/dev/null
