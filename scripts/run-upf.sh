#!/bin/bash
set -e
sudo podman rm -f upf 2>/dev/null || true

sudo podman run -d --name upf \
  --network criu_core5g --ip 10.100.0.200 \
  --cap-add NET_ADMIN --cap-add SYS_ADMIN \
  --user root \
  --device /dev/net/tun \
  --privileged \
  --security-opt seccomp=unconfined \
  --security-opt label=disable \
  --sysctl net.ipv4.ip_forward=1 \
  --sysctl net.ipv4.conf.eth0.proxy_arp=1 \
  -v "$(pwd)/config/upf.yaml:/etc/open5gs/upf.yaml:ro" \
  -v "$(pwd)/entrypoint-upf.sh:/entrypoint-upf.sh:ro" \
  --entrypoint /entrypoint-upf.sh \
  gradiant/open5gs:2.8.0

sleep 3
UPFD=$(pgrep -f open5gs-upfd | head -1)
[[ -n "$UPFD" ]] && sudo nsenter -t $UPFD -n ss -ulpn | grep -E '8805|2152' \
  || echo "AVISO: open5gs-upfd não encontrado — veja podman logs upf"
