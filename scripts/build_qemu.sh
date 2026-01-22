#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_cmd git
require_cmd ninja
require_cmd python3
require_cmd make

QEMU_REPO="$(yver qemu repo)"
QEMU_REF="$(yver qemu ref)"

QEMU_SRC="${SRC_DIR}/qemu"
QEMU_BUILD="${BUILD_DIR}/qemu"

# New: install prefix (artifact this)
QEMU_PREFIX="${OUT_DIR}/runtime/qemu"
QEMU_BINDIR="${QEMU_PREFIX}/bin"
QEMU_INSTALLED="${QEMU_BINDIR}/qemu-system-aarch64"

log "QEMU repo: ${QEMU_REPO} ref: ${QEMU_REF}"
git_checkout_ref "${QEMU_SRC}" "${QEMU_REPO}" "${QEMU_REF}"

mkdir -p "${QEMU_BUILD}" "${QEMU_PREFIX}"
pushd "${QEMU_BUILD}" >/dev/null

# If prefix changes (or we want clean install), force reconfigure
NEED_RECONF=0
if [[ ! -f "build.ninja" ]]; then
  NEED_RECONF=1
else
  # Reconfigure if previous prefix differs
  if [[ -f config-host.mak ]]; then
    if ! grep -qE "^CONFIG_PREFIX=${QEMU_PREFIX}$" config-host.mak 2>/dev/null; then
      NEED_RECONF=1
    fi
  fi
fi

if [[ "${NEED_RECONF}" == "1" ]]; then
  log "Configuring QEMU (prefix=${QEMU_PREFIX})..."
  # Safer to start clean when changing configure args
  rm -f build.ninja config-host.mak || true

  "${QEMU_SRC}/configure" \
    --prefix="${QEMU_PREFIX}" \
    --target-list=aarch64-softmmu \
    --enable-slirp \
    --disable-werror
fi

log "Building QEMU..."
ninja -j"$(nproc)"

log "Installing QEMU into ${QEMU_PREFIX}..."
ninja install

if [[ ! -x "${QEMU_INSTALLED}" ]]; then
  echo "ERROR: Installed QEMU not found at ${QEMU_INSTALLED}" >&2
  exit 1
fi

# Optional: keep the old path working (some scripts may expect BUILD_DIR/qemu/qemu-system-aarch64)
cp -f "${QEMU_INSTALLED}" "${QEMU_BUILD}/qemu-system-aarch64" || true

# Wrapper for artifact usage: sets a stable datadir
mkdir -p "${OUT_DIR}/runtime"
cat > "${OUT_DIR}/runtime/run-qemu-system-aarch64" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# QEMU needs its share dir for pc-bios, keymaps, etc.
export QEMU_DATADIR="${HERE}/qemu/share/qemu"

exec "${HERE}/qemu/bin/qemu-system-aarch64" "$@"
SH
chmod +x "${OUT_DIR}/runtime/run-qemu-system-aarch64"

log "QEMU installed: ${QEMU_INSTALLED}"
log "QEMU wrapper:  ${OUT_DIR}/runtime/run-qemu-system-aarch64"
popd >/dev/null
