#!/bin/bash
set -e

# eth0 do netavark: capturamos IP e gateway, mas o IP vai MIGRAR para o netns aninhado
EXT_CIDR=$(ip -4 -o addr show eth0 | awk '{print $4}')      # 10.100.0.200/24
EXT_IP=${EXT_CIDR%/*}                                        # 10.100.0.200
GW=$(ip -4 route show default | awk '/default/{print $3}')  # 10.100.0.1
echo "eth0 externo: $EXT_CIDR gw $GW (vai migrar p/ o netns aninhado)"

# 1. filho no netns aninhado: o 10.100.0.200 vive AQUI, no veth-upf, junto da ogstun
unshare -n bash -c '
  ip link set lo up
  while ! ip link show veth-upf &>/dev/null; do sleep 0.2; done
  ip link set veth-upf up
  # IP real da UPF (o mesmo do core5g) fica no veth-upf
  ip addr add '"$EXT_IP"'/32 dev veth-upf
  # rota para o gateway via o link ponto-a-ponto (o GW está do outro lado do veth)
  ip route add '"$GW"' dev veth-upf
  ip route add default via '"$GW"' dev veth-upf
  ip tuntap add name ogstun mode tun
  ip addr add 10.45.0.1/16 dev ogstun
  ip link set ogstun up
  iptables-legacy -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE
  sysctl -w net.ipv4.ip_forward=1
  exec /opt/open5gs/bin/open5gs-upfd -c /etc/open5gs/upf.yaml
' &
CHILD=$!

# 2. espera o netns do filho existir e diferir do nosso
MYNS=$(readlink /proc/self/ns/net)
until [ -e /proc/$CHILD/ns/net ] && \
      [ "$(readlink /proc/$CHILD/ns/net)" != "$MYNS" ]; do
  sleep 0.1
done

# 3. cria o par veth; veth-upf vai para o filho (peer veth-ctr fica no netns do container)
ip link add veth-ctr type veth peer name veth-upf
ip link set veth-upf netns $CHILD
ip link set veth-ctr up

# 4. TIRA o 10.100.0.200 do eth0 (ele migrou para o veth-upf) e habilita proxy ARP
ip addr del $EXT_CIDR dev eth0
#sysctl -w net.ipv4.ip_forward=1
#sysctl -w net.ipv4.conf.eth0.proxy_arp=1
sysctl -w net.ipv4.conf.veth-ctr.proxy_arp=1
# rota /32 para alcançar a UPF através do veth-ctr
ip route add $EXT_IP/32 dev veth-ctr
# rota para alcançar a bridge através da eth0
#ip route add 10.100.0.0/24 dev eth0
ip route add default dev eth0

wait $CHILD
