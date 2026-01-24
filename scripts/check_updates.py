#!/usr/bin/env python3
import os
import re
import sys
import json
import yaml
import urllib.request
from dataclasses import dataclass
from typing import Optional, Tuple, Dict, Any

VERSIONS_YML = os.environ.get("VERSIONS_YML", "versions.yml")

# Policy controls (you can tighten later)
ALLOW_MAJOR_BUMPS = os.environ.get("ALLOW_MAJOR_BUMPS", "false").lower() == "true"
ALLOW_RC = os.environ.get("ALLOW_RC", "false").lower() == "true"

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")

@dataclass
class Update:
    name: str
    old: str
    new: str

def normalize_busybox(tag: str) -> str:
    # BusyBox tags are like 1_36_1
    return tag.replace("_", ".")

def http_get_json(url: str, headers: Dict[str, str]) -> Any:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))

def gh_headers() -> Dict[str, str]:
    h = {"Accept": "application/vnd.github+json"}
    if GITHUB_TOKEN:
        h["Authorization"] = f"Bearer {GITHUB_TOKEN}"
    return h

def parse_semver(s: str) -> Optional[Tuple[int,int,int,str]]:
    """
    Parse forms: v2.10.0, 2.10.0, v2024.10, 6.12, etc.
    Returns (major, minor, patch, suffix). patch defaults to 0.
    """
    s0 = s.strip()
    s0 = s0[1:] if s0.startswith("v") else s0

    # allow suffix like -rc1
    m = re.match(r"^(\d+)\.(\d+)(?:\.(\d+))?([\-\.].+)?$", s0)
    if not m:
        return None
    major = int(m.group(1))
    minor = int(m.group(2))
    patch = int(m.group(3) or 0)
    suffix = (m.group(4) or "")
    return (major, minor, patch, suffix)

def semver_is_prerelease(suffix: str) -> bool:
    if not suffix:
        return False
    # treat rc, pre, beta as prerelease
    return bool(re.search(r"(rc|alpha|beta|pre)", suffix, re.IGNORECASE))

def semver_cmp(a: str, b: str) -> int:
    pa = parse_semver(a)
    pb = parse_semver(b)
    if not pa or not pb:
        # fallback lexicographic
        return (a > b) - (a < b)
    amaj, amin, ap, asuf = pa
    bmaj, bmin, bp, bsuf = pb
    if (amaj, amin, ap) != (bmaj, bmin, bp):
        return (amaj, amin, ap) > (bmaj, bmin, bp) and 1 or -1
    # Same numeric core: prefer non-prerelease over prerelease
    a_pre = semver_is_prerelease(asuf)
    b_pre = semver_is_prerelease(bsuf)
    if a_pre != b_pre:
        return -1 if a_pre else 1
    return (asuf > bsuf) - (asuf < bsuf)

def is_allowed_bump(old: str, new: str) -> bool:
    po = parse_semver(old)
    pn = parse_semver(new)
    if not po or not pn:
        return True
    omaj, omin, op, osuf = po
    nmaj, nmin, np, nsuf = pn

    if semver_is_prerelease(nsuf) and not ALLOW_RC:
        return False

    if nmaj != omaj and not ALLOW_MAJOR_BUMPS:
        return False

    return True

def gh_latest_release_tag(owner_repo: str) -> Optional[str]:
    # Prefer releases API; if repo doesn’t use releases, returns 404 -> fallback
    url = f"https://api.github.com/repos/{owner_repo}/releases/latest"
    try:
        j = http_get_json(url, gh_headers())
        return j.get("tag_name")
    except Exception:
        return None

def gh_latest_tag(owner_repo: str) -> Optional[str]:
    # Tags list is ordered by commit date descending (usually good enough)
    url = f"https://api.github.com/repos/{owner_repo}/tags?per_page=50"
    j = http_get_json(url, gh_headers())
    tags = [t.get("name","") for t in j if t.get("name")]
    # Choose the greatest semver-like tag among the first page
    best = None
    for t in tags:
        if not ALLOW_RC and semver_is_prerelease(parse_semver(t)[3] if parse_semver(t) else ""):
            continue
        if best is None or semver_cmp(t, best) > 0:
            best = t
    return best

def kernelorg_latest_stable() -> Optional[str]:
    # kernel.org publishes JSON
    url = "https://www.kernel.org/releases.json"
    j = http_get_json(url, headers={})
    # Find "stable" release
    for rel in j.get("releases", []):
        if rel.get("moniker") == "stable":
            return rel.get("version")
    return None

def repo_to_owner_repo(repo_url: str) -> Optional[str]:
    # supports https://github.com/OWNER/REPO(.git)
    m = re.match(r"^https?://github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$", repo_url.strip())
    if not m:
        return None
    return f"{m.group(1)}/{m.group(2)}"

def main() -> int:
    with open(VERSIONS_YML, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    updates: list[Update] = []

    def maybe_update(component: str, new_ref: str):
        nonlocal updates
        old_ref = str(data[component].get("ref", "")).strip()
        if not old_ref or not new_ref:
            return
        if semver_cmp(new_ref, old_ref) <= 0:
            return
        if not is_allowed_bump(old_ref, new_ref):
            print(f"[skip] {component}: {old_ref} -> {new_ref} (blocked by policy)")
            return
        data[component]["ref"] = new_ref
        updates.append(Update(component, old_ref, new_ref))
        print(f"[bump] {component}: {old_ref} -> {new_ref}")

    # GitHub-based components
    for comp in ["qemu", "busybox", "uboot", "atf"]:
        repo = str(data.get(comp, {}).get("repo", "")).strip()
        owner_repo = repo_to_owner_repo(repo)
        if not owner_repo:
            print(f"[warn] {comp}: repo not github or not parseable: {repo}")
            continue

        tag = gh_latest_release_tag(owner_repo) or gh_latest_tag(owner_repo)
        if not tag:
            continue

        if comp == "busybox":
            old = data[comp]["ref"]
            if semver_cmp(
                normalize_busybox(tag),
                normalize_busybox(old)
            ) > 0:
                maybe_update(comp, tag)
        else:
            maybe_update(comp, tag)

    # Linux: kernel.org stable
    if "linux" in data:
        latest = kernelorg_latest_stable()
        if latest:
            # your versions.yml might store "6.12" or "v6.12.3"; normalize to "vX.Y.Z"
            # keep your style: if old starts with v, add v
            old = str(data["linux"].get("ref", "")).strip()
            if old.startswith("v"):
                latest = "v" + latest
            maybe_update("linux", latest)

    if not updates:
        print("No updates found.")
        return 0

    with open(VERSIONS_YML, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, sort_keys=False)

    # Write a machine-readable summary (useful in workflow)
    with open("out/version-updates.json", "w", encoding="utf-8") as f:
        json.dump([u.__dict__ for u in updates], f, indent=2)

    return 0

if __name__ == "__main__":
    os.makedirs("out", exist_ok=True)
    sys.exit(main())
