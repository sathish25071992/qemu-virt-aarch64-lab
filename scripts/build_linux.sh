#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_cmd make
require_cmd curl
require_cmd tar
require_cmd xz
require_cmd aarch64-linux-gnu-gcc

# Read linux.version from versions.yml
LINUX_VER="$(python3 - <<'PY'
import yaml
d=yaml.safe_load(open("versions.yml"))
print(d["linux"]["version"])
PY
)"

# kernel.org paths:
# https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.tar.xz
MAJOR="${LINUX_VER%%.*}"
TARBALL="linux-${LINUX_VER}.tar.xz"
BASE_URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x"
TARBALL_URL="${BASE_URL}/${TARBALL}"

DL_DIR="${CACHE_DIR}/dl"
SRC_TARBALL="${DL_DIR}/${TARBALL}"
SRC_EXTRACT="${SRC_DIR}/linux-${LINUX_VER}"
LINUX_BUILD="${BUILD_DIR}/linux"

mkdir -p "${DL_DIR}" "${SRC_DIR}" "${LINUX_BUILD}"

log "Linux tarball: ${TARBALL_URL}"

# Download once (cache)
if [[ ! -f "${SRC_TARBALL}" ]]; then
  log "Downloading ${TARBALL}..."
  curl -L --fail --retry 5 --retry-delay 2 -o "${SRC_TARBALL}.tmp" "${TARBALL_URL}"
  mv "${SRC_TARBALL}.tmp" "${SRC_TARBALL}"
else
  log "Using cached tarball: ${SRC_TARBALL}"
fi

# Extract once (cache)
if [[ ! -d "${SRC_EXTRACT}" ]]; then
  log "Extracting Linux source..."
  tar -C "${SRC_DIR}" -xf "${SRC_TARBALL}"
fi

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

# Configure
if [[ ! -f "${LINUX_BUILD}/.config" ]]; then
  log "Configuring Linux (out-of-tree)..."
  make -C "${SRC_EXTRACT}" O="${LINUX_BUILD}" defconfig

  # Baseline config
  cp -f "${ROOT_DIR}/configs/linux/defconfig" "${LINUX_BUILD}/.config"

  # Ensure must-have options
  "${SRC_EXTRACT}/scripts/config" --file "${LINUX_BUILD}/.config" \
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

  make -C "${SRC_EXTRACT}" O="${LINUX_BUILD}" olddefconfig
fi

log "Building Linux Image..."
make -C "${SRC_EXTRACT}" O="${LINUX_BUILD}" -j"$(nproc)" Image

VMLINUX="${LINUX_BUILD}/arch/arm64/boot/Image"
if [[ ! -f "${VMLINUX}" ]]; then
  echo "ERROR: Kernel Image not found at: ${VMLINUX}" >&2
  find "${OUT_DIR}" -maxdepth 8 -type f -name Image -print >&2 || true
  exit 1
fi

cp -f "${VMLINUX}" "${IMG_DIR}/Image"
log "Linux Image -> ${IMG_DIR}/Image"
