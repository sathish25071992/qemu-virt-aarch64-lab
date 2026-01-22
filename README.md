# qemu-virt-aarch64-lab

Build and boot a minimal aarch64 Linux + BusyBox on QEMU `virt` for a CPU matrix.

## What it builds
- QEMU (from source)
- Linux kernel Image (arm64)
- BusyBox static initramfs (cpio.gz)

## Supported platforms (CPU models)
See `platforms.yml`.

## Local usage (Ubuntu 24.04)
```bash
sudo apt-get update
sudo apt-get install -y \
  git build-essential ninja-build pkg-config \
  gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  flex bison bc libssl-dev libncurses-dev \
  python3 python3-yaml expect \
  libglib2.0-dev libpixman-1-dev zlib1g-dev

# build everything for a platform
PLATFORM=virt-cortex-a53 bash scripts/build_all.sh

# run qemu (prints serial to stdout)
PLATFORM=virt-cortex-a53 bash scripts/run_qemu.sh
