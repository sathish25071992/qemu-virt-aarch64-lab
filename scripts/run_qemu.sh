#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

PLATFORM="${PLATFORM:-virt-cortex-a53}"

CPU="$(yplat "${PLATFORM}" cpu)"
MACHINE="$(yplat "${PLATFORM}" machine)"
SMP="$(yplat "${PLATFORM}" smp)"
MEM_MB="$(yplat "${PLATFORM}" mem_mb)"
SERIAL_TELNET_PORT="${SERIAL_TELNET_PORT:-}"
SERIAL_TELNET_HOST="${SERIAL_TELNET_HOST:-127.0.0.1}"

QEMU_BIN="${BUILD_DIR}/qemu/qemu-system-aarch64"
VMLINUX="${IMG_DIR}/Image"
INITRAMFS="${IMG_DIR}/rootfs.cpio.gz"

if [[ ! -x "${QEMU_BIN}" ]]; then
  echo "ERROR: QEMU not built: ${QEMU_BIN}" >&2
  exit 1
fi
if [[ ! -f "${VMLINUX}" || ! -f "${INITRAMFS}" ]]; then
  echo "ERROR: missing images. Run: PLATFORM=${PLATFORM} bash scripts/build_all.sh" >&2
  exit 1
fi

# Validate CPU exists in this QEMU build
if ! "${QEMU_BIN}" -cpu help | grep -qE "(^|[[:space:]])${CPU}([[:space:]]|$)"; then
  echo "ERROR: CPU '${CPU}' not supported by this QEMU build." >&2
  echo "Hint: bump QEMU version in versions.yml (qemu.ref) and rebuild." >&2
  echo "Available CPUs (snippet):" >&2
  "${QEMU_BIN}" -cpu help | head -n 80 >&2 || true
  exit 2
fi

QEMU_ARGS=(
  -M "${MACHINE}" -cpu "${CPU}" -smp "${SMP}" -m "${MEM_MB}"
  -nographic
  -kernel "${VMLINUX}"
  -initrd "${INITRAMFS}"
  -append "console=ttyAMA0 earlycon=pl011,0x09000000 rdinit=/init panic=-1"
  -no-reboot
)

if [[ -n "${SERIAL_TELNET_PORT}" ]]; then
  QEMU_ARGS+=(-serial "telnet:${SERIAL_TELNET_HOST}:${SERIAL_TELNET_PORT},server,nowait")
fi

exec "${QEMU_BIN}" "${QEMU_ARGS[@]}"
