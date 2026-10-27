#!/usr/bin/env bash
# ==============================================================================
# RESULTATS-BF - Extension E4 : Deploiement sans coupure (Rolling Update)
# Role : Ingenieur applicatif
# Description : Met a jour les serveurs applicatifs un par un (Zero-Downtime)
#               en drainant le trafic via HAProxy.
# ==============================================================================

set -euo pipefail

echo -e "\033[1;36m==================================================================\033[0m"
echo -e "\033[1;36m [E4] LANCEMENT DU DEPLOIEMENT SANS COUPURE (ROLLING UPDATE)     \033[0m"
echo -e "\033[1;36m==================================================================\033[0m"

NOEUDS_FILE="config/noeuds.yml"
if [ ! -f "$NOEUDS_FILE" ]; then
    echo -e "\033[1;31mErreur : $NOEUDS_FILE introuvable !\033[0m"
    exit 1
fi

# Extraire la liste des serveurs applicatifs
APP_SERVERS=$(grep -oE "app[0-9]+" "$NOEUDS_FILE" | sort -u || true)

if [ -z "$APP_SERVERS" ]; then
    echo -e "\033[1;31mErreur : Aucun serveur applicatif trouve dans $NOEUDS_FILE !\033[0m"
    exit 1
fi

echo -e "\033[1;33mServeurs detectes : $(echo $APP_SERVERS | tr '\n' ' ')\033[0m"
echo -e "------------------------------------------------------------------"

START_TIME=$(date +%s)

for app in $APP_SERVERS; do
    echo -e "\n\033[1;36m>>> [Etape] Deploiement sur $app...\033[0m"

    # 1. Drainage du trafic dans HAProxy
    echo -n "  1. Isolation de $app dans HAProxy (etat: MAINT)... "
    vagrant ssh lb1 -c "echo 'set server app_servers/$app state maint' | sudo socat stdio /run/haproxy/admin.sock" >/dev/null 2>&1
    echo -e "\033[1;32m[OK]\033[0m"

    # Attendre 2 secondes pour drainer les connexions en vol
    sleep 2

    # 2. Mise a jour du code et redemarrage
    echo -n "  2. Synchronisation du code et redemarrage du service sur $app... "
    vagrant ssh "$app" -c "sudo cp -r /vagrant/app/* /opt/resultats-bf/app/ && sudo systemctl restart resultats-bf" >/dev/null 2>&1
    echo -e "\033[1;32m[OK]\033[0m"

    # 3. Verification de la sonde de sante
    echo -n "  3. Verification de la sonde de sante /sante sur $app... "
    healthy=false
    for i in {1..10}; do
        sleep 1
        status=$(vagrant ssh "$app" -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/sante" 2>/dev/null || echo "000")
        status=$(echo "$status" | tr -d '\r\n')
        if [ "$status" = "200" ]; then
            healthy=true
            break
        fi
    done

    if [ "$healthy" = false ]; then
        echo -e "\033[1;31m[ECHEC : la sonde ne repond pas 200]\033[0m"
        echo -e "\033[1;31mInterruption du deploiement pour proteger la production !\033[0m"
        exit 1
    fi
    echo -e "\033[1;32m[OK (200)]\033[0m"

    # 4. Reintegration dans HAProxy
    echo -n "  4. Reintegration de $app dans le pool actif HAProxy (etat: READY)... "
    vagrant ssh lb1 -c "echo 'set server app_servers/$app state ready' | sudo socat stdio /run/haproxy/admin.sock" >/dev/null 2>&1
    echo -e "\033[1;32m[OK]\033[0m"

    echo -e "  \033[1;32m==> $app est desormais a jour et actif !\033[0m"
done

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo -e "\n------------------------------------------------------------------"
echo -e "\033[1;32m==================================================================\033[0m"
echo -e "\033[1;32m [SUCCES] Deploiement sans coupure termine en ${ELAPSED}s ! \033[0m"
echo -e "\033[1;32m==================================================================\033[0m"
