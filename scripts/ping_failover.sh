#!/bin/bash
# =============================================================
# Ping contínuo resiliente - não depende da interface
# Detecta queda/retorno da conexão e mede o gap
# =============================================================

#TARGET="${1:-8.8.8.8}"
TARGET="${1:-172.16.2.178}"
LOG="ping_failover_$(date +%Y%m%d_%H%M%S).log"
IFACE_PREFIX="wwan"
WAIT_TIME="0.2"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}=== Ping Contínuo com Detecção de Failover ===${NC}"
echo -e "Alvo: $TARGET | Log: $LOG\n"

seq=0
lost=0
down_ts=""
events=()

cleanup() {
#    echo -e "\n\n${YELLOW}=== RESUMO ===${NC}"
    echo "total_de_pings: $seq"
    echo "perdidos: $lost"
    [ $seq -gt 0 ] && echo "perda: $(awk "BEGIN{printf \"%.1f\", $lost/$seq*100}")%"
    echo "downtime: ${gap_s}"
    for e in "${events[@]}"; do echo "  $e"; done
    exit 0
}
trap cleanup INT TERM

#while true; do
while [ $seq -le 149 ]; do
   iface=$(ip link show 2>/dev/null | grep -oP "${IFACE_PREFIX}\d+" | head -1)
    seq=$((seq+1))
    ts=$(date '+%H:%M:%S.%3N')

    if [ -n "$iface" ]; then
        rtt=$(ping -c1 -W "$WAIT_TIME" -I "$iface" "$TARGET" 2>/dev/null \
              | grep -oP 'time=\K[\d.]+')

        if [ -n "$rtt" ]; then
            # Ping OK
            if [ -n "$down_ts" ]; then
                now_ms=$(date +%s%3N)
                gap_ms=$((now_ms - down_ts))
                gap_s=$(awk "BEGIN{printf \"%.3f\", $gap_ms/1000}")
                msg="reconectado:"
                echo -e "[$ts] ${GREEN}${msg}${NC}"
                events+=("$msg $ts")
                down_ts=""
            fi
            echo "[$ts] seq=$seq iface=$iface rtt=${rtt}ms" >> "$LOG"
        else
            lost=$((lost+1))
            if [ -z "$down_ts" ]; then
                down_ts=$(date +%s%3N)
                msg="ping_falhou:"
                echo -e "[$ts] ${RED}${msg}${NC}"
                events+=("$msg $ts")
            fi
            echo "[$ts] seq=$seq iface=$iface FAIL" >> "$LOG"
        fi
    else
      
       lost=$((lost+1))
        if [ -z "$down_ts" ]; then
            down_ts=$(date +%s%3N)
            msg="▼ Interface $IFACE_PREFIX ausente"
            echo -e "[$ts] ${RED}${msg}${NC}"
            events+=("$ts | $msg")
        fi
        echo "[$ts] seq=$seq NO_IFACE" >> "$LOG"
    fi

    sleep "$WAIT_TIME"
done

cleanup
