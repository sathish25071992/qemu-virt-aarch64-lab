#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_cmd git
require_cmd make
require_cmd aarch64-linux-gnu-gcc
require_cmd cpio
require_cmd gzip

BUSYBOX_REPO="$(yver busybox repo)"
BUSYBOX_REF="$(yver busybox ref)"

BUSYBOX_SRC="${SRC_DIR}/busybox"
BUSYBOX_BUILD="${BUILD_DIR}/busybox"
ROOTFS_DIR="${BUILD_DIR}/rootfs"

log "BusyBox repo: ${BUSYBOX_REPO} ref: ${BUSYBOX_REF}"
git_checkout_ref "${BUSYBOX_SRC}" "${BUSYBOX_REPO}" "${BUSYBOX_REF}"

# BusyBox is strict; keep source tree clean (helps with cached trees in CI)
pushd "${BUSYBOX_SRC}" >/dev/null
git reset --hard
git clean -ffdqx
popd >/dev/null

# Fresh output dirs (avoid stale configs)
rm -rf "${BUSYBOX_BUILD}" "${ROOTFS_DIR}"
mkdir -p "${BUSYBOX_BUILD}" "${ROOTFS_DIR}"

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

CFG_SNAPSHOT="${ROOT_DIR}/configs/busybox/busybox-aarch64-static.config"

log "Configuring BusyBox from frozen .config"

rm -rf "${BUSYBOX_BUILD}"
mkdir -p "${BUSYBOX_BUILD}"

cp -f "${CFG_SNAPSHOT}" "${BUSYBOX_BUILD}/.config"

# Optional but recommended for future BusyBox versions
NEWLINES="${BUSYBOX_BUILD}/.kconfig_newlines"
printf '\n%.0s' {1..5000} > "${NEWLINES}"

make -C "${BUSYBOX_SRC}" \
  O="${BUSYBOX_BUILD}" \
  ARCH=arm64 \
  CROSS_COMPILE=aarch64-linux-gnu- \
  oldconfig < "${NEWLINES}"

# Enforce static
if ! grep -q '^CONFIG_STATIC=y' "${BUSYBOX_BUILD}/.config"; then
  echo "ERROR: BusyBox config is not static" >&2
  exit 1
fi

export LDFLAGS="-static"

log "Building BusyBox..."
make -C "${BUSYBOX_SRC}" O="${BUSYBOX_BUILD}" -j"$(nproc)"
make -C "${BUSYBOX_SRC}" O="${BUSYBOX_BUILD}" CONFIG_PREFIX="${ROOTFS_DIR}" install

# Minimal rootfs structure
mkdir -p "${ROOTFS_DIR}/"{proc,sys,dev,etc,tmp,root}

# /init
cat > "${ROOTFS_DIR}/init" <<'SH'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

echo "Booted initramfs."
uname -a || true
echo "Dropping to shell. Type 'poweroff' to exit."

# cttyhack helps if console is weird; harmless otherwise
exec cttyhack sh
SH
chmod +x "${ROOTFS_DIR}/init"

# Create initramfs
pushd "${ROOTFS_DIR}" >/dev/null
find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > "${IMG_DIR}/rootfs.cpio.gz"
popd >/dev/null

log "Initramfs -> ${IMG_DIR}/rootfs.cpio.gz"
