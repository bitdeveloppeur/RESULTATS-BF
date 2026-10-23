#!/bin/bash
# Script de provisionnement de la base de données primaire (bdd1)
# Rôle : Ingénieur données

set -e

echo "=== Configuration PostgreSQL primaire (bdd1) ==="

# 1. Installer PostgreSQL 14
echo "Installation PostgreSQL 14..."
apt-get update -qq
apt-get install -y postgresql postgresql-contrib

# 2. Démarrer PostgreSQL
echo "Démarrage PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# 3. Créer les utilisateurs et la base de données
echo " Création utilisateurs et base de données..."
sudo -u postgres psql <<EOF
-- Créer l'utilisateur applicatif
CREATE USER resultats_user WITH PASSWORD 'changeme_password';

-- Créer l'utilisateur de réplication
CREATE USER replication_user WITH REPLICATION LOGIN PASSWORD 'changeme_replication';

-- Créer la base de données
CREATE DATABASE resultats_bf OWNER resultats_user;

-- Donner tous les privilèges
GRANT ALL PRIVILEGES ON DATABASE resultats_bf TO resultats_user;
EOF

# 4. Créer la table et générer les données
echo "Création de la table resultats..."
sudo -u postgres psql -d resultats_bf <<EOF
-- Créer la table resultats
CREATE TABLE resultats (
    id SERIAL PRIMARY KEY,
    matricule VARCHAR(20) UNIQUE NOT NULL,
    nom VARCHAR(100) NOT NULL,
    serie VARCHAR(10) NOT NULL,
    moyenne DECIMAL(4,2) NOT NULL,
    admis BOOLEAN NOT NULL
);

-- Générer 50 000 candidats avec generate_series
INSERT INTO resultats (matricule, nom, serie, moyenne, admis)
SELECT
    LPAD(i::TEXT, 6, '0') AS matricule,
    'CANDIDAT_' || i AS nom,
    CASE (i % 4)
        WHEN 0 THEN 'A'
        WHEN 1 THEN 'C'
        WHEN 2 THEN 'D'
        ELSE 'S'
    END AS serie,
    ROUND((RANDOM() * 10 + 5)::NUMERIC, 2) AS moyenne,
    CASE WHEN RANDOM() > 0.3 THEN true ELSE false END AS admis
FROM generate_series(1, 50000) AS i;

-- Donner les droits à resultats_user
GRANT ALL PRIVILEGES ON TABLE resultats TO resultats_user;
GRANT USAGE, SELECT ON SEQUENCE resultats_id_seq TO resultats_user;

-- Vérifier le nombre de lignes
SELECT COUNT(*) AS nombre_candidats FROM resultats;
EOF

# 5. Configurer PostgreSQL pour accepter les connexions réseau ET la réplication
echo "🔧 Configuration des connexions réseau et réplication..."

# Modifier postgresql.conf pour écouter sur toutes les interfaces
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf

# Configurer les WAL pour la réplication streaming
cat >> /etc/postgresql/*/main/postgresql.conf <<EOF

# Configuration pour la réplication streaming
wal_level = replica
max_wal_senders = 3
max_replication_slots = 3
EOF

# Modifier pg_hba.conf pour autoriser les connexions depuis le réseau privé
cat >> /etc/postgresql/*/main/pg_hba.conf <<EOF

# Autoriser les connexions depuis le réseau privé 192.168.63.0/24
host    resultats_bf    resultats_user    192.168.63.0/24    md5
host    replication     replication_user  192.168.63.0/24    md5
EOF

# 6. Redémarrer PostgreSQL
echo "Redémarrage PostgreSQL..."
systemctl restart postgresql

# 7. Vérifier le statut
echo "Statut PostgreSQL:"
systemctl status postgresql --no-pager

# 8. Test de connexion
echo "Test de connexion..."
sudo -u postgres psql -d resultats_bf -c "SELECT COUNT(*) as total FROM resultats;"

echo "Configuration de bdd1 terminée !"
echo " Base de données: resultats_bf"
echo " Utilisateur applicatif: resultats_user"
echo "Utilisateur réplication: replication_user"
echo "50 000 candidats générés"
echo "PostgreSQL écoute sur: 192.168.63.31:5432"
echo "Réplication configurée (en attente de bdd2)"
