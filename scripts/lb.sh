#!/bin/bash
# Script de provisionnement du Load Balancer (lb1)
# Rôle : Architecte réseau et répartition

set -e  # Arrêter le script si une commande échoue

echo "=== Installation HAProxy sur lb1 ==="

# 1. Mettre à jour les paquets
apt-get update -qq

# 2. Installer HAProxy
apt-get install -y haproxy

# 3. Lire la configuration des noeuds depuis le fichier YAML
# On extrait tous les serveurs applicatifs (role: "app")
echo "=== Génération de la configuration HAProxy ==="

# Créer la configuration HAProxy
cat > /etc/haproxy/haproxy.cfg <<'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

# Frontend - Point d'entrée pour les requêtes
frontend http_front
    bind *:80
    default_backend app_servers

# Backend - Pool de serveurs applicatifs
backend app_servers
    balance roundrobin
    
    # Sonde de santé : teste GET /sante toutes les 3 secondes
    # Si 2 échecs consécutifs, le serveur est écarté
    # Si 2 succès consécutifs, le serveur est remis en service
    option httpchk GET /sante
    http-check expect status 200
    
EOF

# 4. Ajouter dynamiquement les serveurs applicatifs
# On lit le fichier /vagrant/config/noeuds.yml
if [ -f /vagrant/config/noeuds.yml ]; then
    echo "    # Serveurs générés automatiquement depuis config/noeuds.yml" >> /etc/haproxy/haproxy.cfg
    
    # Extraire les noms et IPs des serveurs app depuis le YAML
    # Méthode simple sans dépendances (grep + awk)
    awk '/- :nom: app[0-9]+/{name=$3} /:ip:/{ip=$2; if(name) print name, ip; name=""}' /vagrant/config/noeuds.yml | while IFS=$'\r\n' read nom ip; do
        # Nettoyer les retours chariot Windows
        nom=$(echo "$nom" | tr -d '\r')
        ip=$(echo "$ip" | tr -d '\r')
        echo "    server $nom $ip:3000 check inter 3s fall 2 rise 2" >> /etc/haproxy/haproxy.cfg
    done
else
    echo "ERREUR : /vagrant/config/noeuds.yml introuvable !"
    exit 1
fi

# 5. Afficher la configuration générée (pour debug)
echo "=== Configuration HAProxy générée ==="
cat /etc/haproxy/haproxy.cfg

# 6. Tester la configuration
haproxy -c -f /etc/haproxy/haproxy.cfg

# 7. Activer et démarrer HAProxy
systemctl enable haproxy
systemctl restart haproxy

# 8. Vérifier le statut
systemctl status haproxy --no-pager


# ============================================================
# E1 — Keepalived : VIP partagée entre lb1 (MASTER) et lb2 (BACKUP)
# ============================================================
echo "=== Configuration Keepalived (VRRP) ==="

apt-get install -y keepalived

HOST=$(hostname)
if [ "$HOST" = "lb1" ]; then
    STATE="MASTER"
    PRIORITY=100
else
    STATE="BACKUP"
    PRIORITY=90
fi

# Détection auto de l'interface du réseau privé
IFACE=$(ip -o -4 addr show | grep "192.168.63" | awk '{print $2}' | head -1)
echo "Interface détectée : $IFACE"

cat > /etc/keepalived/keepalived.conf <<EOF
vrrp_instance VI_1 {
    state $STATE
    interface $IFACE
    virtual_router_id 51
    priority $PRIORITY
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass ResultatsBF2026
    }
    virtual_ipaddress {
        192.168.63.10/24
    }
}
EOF

systemctl enable keepalived
systemctl restart keepalived
echo "Keepalived démarré en $STATE sur $HOST (VIP = 192.168.63.10)"

echo "=== HAProxy installé et configuré avec succès ==="
echo "Accès web : http://192.168.63.11"
echo "Depuis l'hôte : http://localhost:8080"
