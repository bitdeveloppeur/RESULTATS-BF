#!/bin/bash
# Script de provisionnement de la base de données réplique (bdd2)
# Rôle : Ingénieur données
# Réplication streaming depuis bdd1 (192.168.63.31)

set -e

echo "=== Configuration PostgreSQL réplique (bdd2) ==="

PRIMARY_HOST="192.168.63.31"
PRIMARY_PORT="5432"
REPLICATION_USER="replication_user"
REPLICATION_PASSWORD="changeme_replication"

# 1. Installer PostgreSQL 14
echo "Installation PostgreSQL 14..."
apt-get update -qq
apt-get install -y postgresql postgresql-contrib

# 2. Arrêter PostgreSQL
echo "Arrêt de PostgreSQL..."
systemctl stop postgresql

# 3. Nettoyer le répertoire de données
echo "Nettoyage du répertoire de données..."
rm -rf /var/lib/postgresql/14/main/*

# 4. Créer le fichier .pgpass pour l'authentification automatique
echo "Configuration de l'authentification..."
cat > /var/lib/postgresql/.pgpass << EOF
${PRIMARY_HOST}:${PRIMARY_PORT}:replication:${REPLICATION_USER}:${REPLICATION_PASSWORD}
EOF
chown postgres:postgres /var/lib/postgresql/.pgpass
chmod 600 /var/lib/postgresql/.pgpass

# 5. Effectuer la copie initiale avec pg_basebackup
echo "Copie initiale depuis bdd1 (cela peut prendre quelques minutes)..."
sudo -u postgres pg_basebackup \
    -h ${PRIMARY_HOST} \
    -D /var/lib/postgresql/14/main \
    -U ${REPLICATION_USER} \
    -v \
    -P \
    -X stream \
    -C \
    -S replica_slot_bdd2 \
    -R

# 6. Configurer postgresql.conf pour la réplique
echo "Configuration de la réplique..."
cat >> /etc/postgresql/14/main/postgresql.conf << EOF

# Configuration réplique
hot_standby = on
wal_level = replica
max_wal_senders = 3
max_replication_slots = 3
EOF

# 7. Démarrer PostgreSQL en mode réplique
echo "Démarrage PostgreSQL en mode réplique..."
systemctl start postgresql
systemctl enable postgresql

# 8. Attendre que la réplication démarre
echo "Attente du démarrage de la réplication..."
sleep 5

# 9. Vérifier le statut de la réplication
echo "Vérification du statut de réplication..."
sudo -u postgres psql -d resultats_bf -c "SELECT pg_is_in_recovery();" || echo "En attente de connexion au primaire..."

# 10. Tester la lecture (la réplique est en lecture seule)
echo "Test de lecture sur la réplique..."
sudo -u postgres psql -d resultats_bf -c "SELECT COUNT(*) as total_candidats FROM resultats;" || echo "⚠️  Données pas encore répliquées"

echo "Configuration de bdd2 (réplique) terminée !"
echo "Réplication depuis: ${PRIMARY_HOST}:${PRIMARY_PORT}"
echo "Mode: Lecture seule (hot standby)"
echo "En cas d'erreur, vérifier que bdd1 est démarrée et configurée pour la réplication"
