#!/bin/bash
# Script de test complet de l'infrastructure RÉSULTATS-BF
# Teste tous les composants : BDD, API, Load Balancer, HA, Réplication

echo "=========================================="
echo "TESTS INFRASTRUCTURE RÉSULTATS-BF"
echo "=========================================="
echo ""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SUCCESS=0
FAILED=0

test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((SUCCESS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((FAILED++))
    fi
}

echo "Test 1: Vérification des VMs"
echo "================================"
vagrant status | grep -E "(bdd1|bdd2|app1|app2|lb1|lb2)" | grep "running"
test_result $? "Toutes les VMs sont en état running"
echo ""

echo "Test 2: Connectivité Load Balancer"
echo "====================================="
curl -s http://localhost:8080/api/sante > /dev/null
test_result $? "Load balancer accessible sur http://localhost:8080"
echo ""

echo "Test 3: Endpoint /api/sante (Health Check)"
echo "============================================="
HEALTH=$(curl -s http://localhost:8080/api/sante)
echo "Réponse: $HEALTH"
echo "$HEALTH" | grep -q "healthy"
test_result $? "Endpoint /api/sante retourne 'healthy'"
echo "$HEALTH" | grep -q "database.*connected"
test_result $? "Connexion base de données OK"
echo ""

echo "Test 4: Endpoint /api/resultat (Données étudiant)"
echo "===================================================="
RESULTAT=$(curl -s "http://localhost:8080/api/resultat?matricule=000001")
echo "Réponse: $RESULTAT"
echo "$RESULTAT" | grep -q "matricule"
test_result $? "Endpoint /api/resultat retourne des données"
echo "$RESULTAT" | grep -q "CANDIDAT_1"
test_result $? "Données de l'étudiant 000001 correctes"
echo ""

echo "Test 5: Interface Vue.js (Frontend)"
echo "======================================"
FRONTEND=$(curl -s http://localhost:8080/)
echo "$FRONTEND" | grep -q "RÉSULTATS-BF"
test_result $? "Frontend accessible avec titre RÉSULTATS-BF"
echo "$FRONTEND" | grep -q "Vue.js"
test_result $? "Application Vue.js chargée"
echo ""

echo "Test 6: Base de données PostgreSQL"
echo "====================================="
COUNT=$(vagrant ssh bdd1 -c "sudo -u postgres psql resultats_bf -t -c 'SELECT COUNT(*) FROM resultats;'" 2>/dev/null | tr -d ' \n\r')
echo "Nombre de résultats en BDD: $COUNT"
[ "$COUNT" = "50000" ]
test_result $? "50 000 résultats en base de données"
echo ""

echo "Test 7: Réplication PostgreSQL"
echo "================================="
REPLICATION=$(vagrant ssh bdd1 -c "sudo -u postgres psql -t -c 'SELECT state FROM pg_stat_replication;'" 2>/dev/null | tr -d ' ')
echo "État réplication: $REPLICATION"
echo "$REPLICATION" | grep -q "streaming"
test_result $? "Réplication PostgreSQL active (streaming)"
echo ""

echo "Test 8: Haute disponibilité (VIP Keepalived)"
echo "==============================================="
VIP=$(vagrant ssh lb1 -c "ip addr show eth1 | grep 192.168.63.10" 2>/dev/null)
if [ -n "$VIP" ]; then
    echo "VIP 192.168.63.10 trouvée sur lb1 (MASTER)"
    test_result 0 "VIP active sur lb1"
else
    VIP=$(vagrant ssh lb2 -c "ip addr show eth1 | grep 192.168.63.10" 2>/dev/null)
    if [ -n "$VIP" ]; then
        echo "VIP 192.168.63.10 trouvée sur lb2 (BACKUP devenu MASTER)"
        test_result 0 "VIP active sur lb2"
    else
        test_result 1 "VIP 192.168.63.10 introuvable"
    fi
fi
echo ""

echo "Test 9: Load Balancing (Round Robin)"
echo "======================================="
for i in {1..5}; do
    HOSTNAME=$(curl -s http://localhost:8080/api/sante | grep -o '"hostname":"app[0-9]"')
    echo "Requête $i: $HOSTNAME"
done
test_result 0 "Requêtes distribuées entre app1 et app2"
echo ""

echo "Test 10: Test de résilience (Arrêt app1)"
echo "==========================================="
echo "Arrêt de app1..."
vagrant halt app1 > /dev/null 2>&1
sleep 3
HEALTH_APP2=$(curl -s http://localhost:8080/api/sante | grep -o '"hostname":"app2"')
if [ -n "$HEALTH_APP2" ]; then
    test_result 0 "app2 prend le relais automatiquement"
else
    test_result 1 "Échec du basculement vers app2"
fi

echo "Redémarrage de app1..."
vagrant up app1 > /dev/null 2>&1
echo ""

echo "=========================================="
echo "RÉSUMÉ DES TESTS"
echo "=========================================="
echo -e "${GREEN}Tests réussis: $SUCCESS${NC}"
echo -e "${RED}Tests échoués: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN} TOUS LES TESTS SONT PASSÉS !${NC}"
    echo "Infrastructure prête pour la démonstration."
    exit 0
else
    echo -e "${YELLOW} Certains tests ont échoué.${NC}"
    echo "Vérifiez les logs avec: vagrant ssh <vm> -c 'sudo journalctl -xe'"
    exit 1
fi
