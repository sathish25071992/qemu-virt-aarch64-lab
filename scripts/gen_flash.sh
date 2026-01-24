#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_cmd dd
require_cmd truncate

IMG_DIR="${IMG_DIR:-${ROOT_DIR}/out/images}"

BL1="${IMG_DIR}/bl1.bin"
FIP="${IMG_DIR}/fip.bin"
FLASH="${IMG_DIR}/flash.bin"

if [[ ! -f "${BL1}" || ! -f "${FIP}" ]]; then
  echo "ERROR: Missing ${BL1} or ${FIP}. Run scripts/build_uboot.sh and scripts/build_atf.sh first." >&2
  exit 1
fi

# TF-A QEMU flash layout:
# - bl1.bin at offset 0
# - fip.bin at offset 64 * 4096 (0x40000)
# Create a 64MiB flash image (size can be adjusted; 64MiB is typical)
log "Generating ${FLASH}"
rm -f "${FLASH}"
truncate -s $((64*1024*1024)) "${FLASH}"

dd if="${BL1}" of="${FLASH}" bs=4096 conv=notrunc status=none
dd if="${FIP}" of="${FLASH}" bs=4096 seek=64 conv=notrunc status=none

log "flash.bin -> ${FLASH} (bl1 @0, fip @0x40000)"
