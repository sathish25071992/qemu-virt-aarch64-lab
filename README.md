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

## GitHub Actions runners
- Workflows default to `ubuntu-24.04`.
- To run on a self-hosted machine, set repository variable `RUNNER_LABEL` to your runner label (for example `self-hosted`); both CI jobs will pick it up.
- The manual workflow also exposes a `runner_label` input so you can override the runner per dispatch.
- Ensure the chosen runner has the apt packages listed in the workflows pre-installed or installable with `sudo apt-get`.

## Manual workflow tips
- Manual run starts QEMU with its serial console exposed via telnet on `serial_telnet_port` (default `4321`), then opens a tmate session that auto-runs telnet. When you connect to the tmate session you land directly in the serial console; exiting telnet ends the tmate session and the workflow moves on.
- Use `tmate_timeout_minutes` to control how long the tmate session stays up before auto-continuing (default 20).
