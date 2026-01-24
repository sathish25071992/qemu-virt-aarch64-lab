#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

bash scripts/build_qemu.sh
bash scripts/build_linux.sh
bash scripts/build_uboot.sh
bash scripts/build_atf.sh
bash scripts/gen_flash.sh
bash scripts/build_busybox_rootfs.sh

log "Common build complete."