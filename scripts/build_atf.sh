#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_cmd git
require_cmd make
require_cmd aarch64-linux-gnu-gcc

ATF_REPO="$(yver atf repo)"
ATF_REF="$(yver atf ref)"

ATF_SRC="${SRC_DIR}/atf"
ATF_BUILD="${BUILD_DIR}/atf"
IMG_DIR="${IMG_DIR:-${ROOT_DIR}/out/images}"

# BL33 must be U-Boot (built by build_uboot.sh)
BL33_BIN="${IMG_DIR}/u-boot.bin"

log "TF-A repo: ${ATF_REPO} ref: ${ATF_REF}"
git_checkout_ref "${ATF_SRC}" "${ATF_REPO}" "${ATF_REF}"

if [[ ! -f "${BL33_BIN}" ]]; then
  echo "ERROR: BL33 not found at ${BL33_BIN}. Run scripts/build_uboot.sh first." >&2
  exit 1
fi

rm -rf "${ATF_BUILD}"
mkdir -p "${ATF_BUILD}" "${IMG_DIR}"

export CROSS_COMPILE=aarch64-linux-gnu-

# Build BL1 + FIP for QEMU platform, packaging U-Boot as BL33
log "Building TF-A (PLAT=qemu) with BL33=${BL33_BIN}"
make -C "${ATF_SRC}" \
  BUILD_BASE="${ATF_BUILD}" \
  PLAT=qemu \
  DEBUG=0 \
  BL33="${BL33_BIN}" \
  all fip

# Common TF-A output paths:
# BUILD_BASE/qemu/release/bl1.bin and fip.bin
BL1="${ATF_BUILD}/qemu/release/bl1.bin"
FIP="${ATF_BUILD}/qemu/release/fip.bin"

if [[ ! -f "${BL1}" || ! -f "${FIP}" ]]; then
  echo "ERROR: TF-A outputs not found: ${BL1} / ${FIP}" >&2
  echo "Check TF-A build logs and paths under: ${ATF_BUILD}/qemu" >&2
  exit 1
fi

cp -f "${BL1}" "${IMG_DIR}/bl1.bin"
cp -f "${FIP}" "${IMG_DIR}/fip.bin"
log "TF-A -> ${IMG_DIR}/bl1.bin, ${IMG_DIR}/fip.bin"
