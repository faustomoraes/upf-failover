#!/bin/bash
set -e
T0=$(date +%s.%N)
sudo podman container checkpoint upf \
  --tcp-established --file-locks --leave-running --keep
T1=$(date +%s.%N)
echo "checkpoint: $(echo "$T1 - $T0" | bc) s"
echo "UPF viva? $(sudo podman ps --filter name=upf --format '{{.Status}}')"
sudo find /var/lib/containers/storage -name dump.log 2>/dev/null \
  | xargs sudo grep -iE 'veth|tun|external|error|peer' 2>/dev/null | tail
