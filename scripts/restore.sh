#!/bin/bash
set -e
EXT_IP=10.100.0.200
EXT_CIDR=10.100.0.200/24

T0=$(date +%s.%N)
sudo podman container restore upf --tcp-established --file-locks --keep
RC=$?
T1=$(date +%s.%N)

if [[ $RC -ne 0 ]]; then
    echo "RESTORE FALHOU:"
    sudo find /var/lib/containers/storage -name restore.log 2>/dev/null \
      | xargs sudo grep -iE 'error|peer|busy|tun|veth' 2>/dev/null | tail -15
    exit 1
fi

# --- POST-RESTORE: reaplica o roteamento no netns do CONTAINER (não dumpado) ---
CTRPID=$(sudo podman inspect upf --format '{{.State.Pid}}')

#sudo podman exec upf ip link set veth0 name veth-ctr

sudo nsenter -t $CTRPID -n bash -c "
  ip link set veth0 name veth-ctr 2>/dev/null || true
  ip link set veth-ctr up 2>/dev/null || true
  ip addr del $EXT_CIDR dev eth0 2>/dev/null || true
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  sysctl -w net.ipv4.conf.eth0.proxy_arp=1 >/dev/null
  sysctl -w net.ipv4.conf.veth-ctr.proxy_arp=1 >/dev/null
  ip route replace 10.100.0.1/32 dev eth0
  ip route replace default via 10.100.0.1 dev eth0 onlink
  ip route replace $EXT_IP/32 dev veth-ctr
"

T2=$(date +%s.%N)
echo "downtime restore: $(echo "$T1 - $T0" | bc) s"
echo "downtime total (c/ post-restore): $(echo "$T2 - $T0" | bc) s"

# --- validação ---
UPFD=$(pgrep -f open5gs-upfd | head -1)
echo "--- netns aninhado (deve ter veth-upf 10.100.0.200/32 + ogstun) ---"
sudo nsenter -t $UPFD -n conntrack -F 2>/dev/null 
sudo nsenter -t $UPFD -n ip -br addr
sudo nsenter -t $UPFD -n ss -ulpn | grep -E '8805|2152'
echo "--- teste de alcance ao gateway ---"
sudo nsenter -t $UPFD -n ping -c2 10.100.0.1
