#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/out"
CACHE_DIR="${OUT_DIR}/cache"
SRC_DIR="${CACHE_DIR}/src"
BUILD_DIR="${OUT_DIR}/build"
IMG_DIR="${OUT_DIR}/images"

VERSIONS_FILE="${ROOT_DIR}/versions.yml"
PLATFORMS_FILE="${ROOT_DIR}/platforms.yml"

mkdir -p "${OUT_DIR}" "${CACHE_DIR}" "${SRC_DIR}" "${BUILD_DIR}" "${IMG_DIR}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

# Get ref/repo from versions.yml (python+yaml)
yver() {
  local key="$1" field="$2"
  python3 - "$key" "$field" <<'PY'
import sys, yaml
key, field = sys.argv[1], sys.argv[2]
d = yaml.safe_load(open("versions.yml"))
print(d[key][field])
PY
}

# Get platform fields from platforms.yml
yplat() {
  local platform="$1" field="$2"
  python3 - "$platform" "$field" <<'PY'
import sys, yaml
pname, field = sys.argv[1], sys.argv[2]
d = yaml.safe_load(open("platforms.yml"))
plats = d["aarch64"]
p = next((x for x in plats if x["name"] == pname), None)
if not p:
  raise SystemExit(f"Unknown PLATFORM: {pname}")
print(p[field])
PY
}

git_checkout_ref() {
  local dir="$1" repo="$2" ref="$3"
  if [[ ! -d "$dir/.git" ]]; then
    git clone --depth 1 "$repo" "$dir"
  fi
  pushd "$dir" >/dev/null
  git fetch --tags --force --prune
  # try tag/branch/sha
  git checkout -f "$ref" || git checkout -f "tags/$ref" || git checkout -f "origin/$ref"
  popd >/dev/null
}

log() { echo "[$(date +'%H:%M:%S')] $*"; }
