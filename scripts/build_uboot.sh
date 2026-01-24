#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_cmd git
require_cmd make
require_cmd aarch64-linux-gnu-gcc

UBOOT_REPO="$(yver uboot repo)"
UBOOT_REF="$(yver uboot ref)"

UBOOT_SRC="${SRC_DIR}/uboot"
UBOOT_BUILD="${BUILD_DIR}/uboot"
IMG_DIR="${IMG_DIR:-${ROOT_DIR}/out/images}"

log "U-Boot repo: ${UBOOT_REPO} ref: ${UBOOT_REF}"
git_checkout_ref "${UBOOT_SRC}" "${UBOOT_REPO}" "${UBOOT_REF}"

rm -rf "${UBOOT_BUILD}"
mkdir -p "${UBOOT_BUILD}" "${IMG_DIR}"

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

log "Configuring U-Boot (qemu_arm64_defconfig)"
make -C "${UBOOT_SRC}" O="${UBOOT_BUILD}" qemu_arm64_defconfig

log "Building U-Boot"
make -C "${UBOOT_SRC}" O="${UBOOT_BUILD}" -j"$(nproc)"

# BL33 payload for TF-A
cp -f "${UBOOT_BUILD}/u-boot.bin" "${IMG_DIR}/u-boot.bin"
log "U-Boot -> ${IMG_DIR}/u-boot.bin"
