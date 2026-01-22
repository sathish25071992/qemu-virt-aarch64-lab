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

mkdir -p "${BUSYBOX_BUILD}" "${ROOTFS_DIR}"

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

FRAG="${ROOT_DIR}/configs/busybox/defconfig"
CFG="${BUSYBOX_BUILD}/.config"

log "Configuring BusyBox (defconfig + fragment, no scripts/config)..."

# Always start from BusyBox defconfig baseline
make -C "${BUSYBOX_SRC}" O="${BUSYBOX_BUILD}" defconfig

# Apply fragment by overriding symbols in .config
# We remove any existing line for the symbol, then append our desired value.
apply_kv () {
  local key="$1"
  local val="$2"
  # delete existing CONFIG_KEY=... and "# CONFIG_KEY is not set"
  sed -i -E \
    -e "/^${key}=.*/d" \
    -e "/^# ${key} is not set/d" \
    "${CFG}"
  echo "${key}=${val}" >> "${CFG}"
}

apply_notset () {
  local key="$1"
  sed -i -E \
    -e "/^${key}=.*/d" \
    -e "/^# ${key} is not set/d" \
    "${CFG}"
  echo "# ${key} is not set" >> "${CFG}"
}

if [[ -f "${FRAG}" ]]; then
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" || "${line}" =~ ^# ]] && continue

    if [[ "${line}" =~ ^(CONFIG_[A-Za-z0-9_]+)=y$ ]]; then
      apply_kv "${BASH_REMATCH[1]}" "y"
    elif [[ "${line}" =~ ^(CONFIG_[A-Za-z0-9_]+)=m$ ]]; then
      apply_kv "${BASH_REMATCH[1]}" "m"
    elif [[ "${line}" =~ ^(CONFIG_[A-Za-z0-9_]+)=n$ ]]; then
      apply_notset "${BASH_REMATCH[1]}"
    elif [[ "${line}" =~ ^(CONFIG_[A-Za-z0-9_]+)=(.*)$ ]]; then
      # keep raw value (may include quotes or numbers)
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      # if val is exactly n, treat as not set
      if [[ "${val}" == "n" ]]; then
        apply_notset "${key}"
      else
        apply_kv "${key}" "${val}"
      fi
    else
      # ignore anything we don't understand
      :
    fi
  done < "${FRAG}"
fi

# Resolve NEW options non-interactively (defaults).
# With `set -o pipefail`, `yes` may get SIGPIPE (rc=141) after make stops reading.
# Treat 141 as success.
set +e
yes "" | make -C "${BUSYBOX_SRC}" O="${BUSYBOX_BUILD}" oldconfig
rc=$?
set -e

if [[ "$rc" -ne 0 && "$rc" -ne 141 ]]; then
  exit "$rc"
fi

log "Building BusyBox..."
make -C "${BUSYBOX_SRC}" O="${BUSYBOX_BUILD}" -j"$(nproc)"
make -C "${BUSYBOX_SRC}" O="${BUSYBOX_BUILD}" CONFIG_PREFIX="${ROOTFS_DIR}" install

mkdir -p "${ROOTFS_DIR}/"{proc,sys,dev,etc,tmp,root}

cat > "${ROOTFS_DIR}/init" <<'SH'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

echo "Booted initramfs."
uname -a || true
echo "Dropping to shell. Type 'poweroff' to exit."
exec sh
SH
chmod +x "${ROOTFS_DIR}/init"

pushd "${ROOTFS_DIR}" >/dev/null
find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > "${IMG_DIR}/rootfs.cpio.gz"
popd >/dev/null

log "Initramfs -> ${IMG_DIR}/rootfs.cpio.gz"
