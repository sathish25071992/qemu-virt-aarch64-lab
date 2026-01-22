#!/usr/bin/env bash
set -euo pipefail

# Common build once
bash scripts/build_all.sh

# Test all CPUs
for p in virt-cortex-a53 virt-cortex-a72 virt-neoverse-n1 virt-cortex-a710; do
  echo "=== Testing $p ==="
  expect -f scripts/smoke_test.expect "$p" | tee "out/serial-$p.log"
done
