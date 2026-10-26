#!/bin/bash
# Script de provisionnement des serveurs applicatifs (app1, app2, ...)
# Rôle : Ingénieur applicatif

set -e

echo "=== Configuration serveur applicatif $(hostname) ==="

# 1. Installer Python 3 et pip
echo "Installation Python 3..."
apt-get update -qq
apt-get install -y python3 python3-pip python3-venv

# 2. Créer le répertoire de l'application
echo "Création du répertoire /opt/resultats-bf..."
mkdir -p /opt/resultats-bf
cd /opt/resultats-bf

# 3. Copier l'application depuis /vagrant/app
echo " Copie de l'application..."
cp -r /vagrant/app /opt/resultats-bf/

# 3b. Copier l'interface web depuis /vagrant/web
echo " Copie de l'interface web..."
cp -r /vagrant/web /opt/resultats-bf/app/

# 4. Créer un virtual env et installer les dépendances
echo "Installation des dépendances Python..."
python3 -m venv /opt/resultats-bf/venv
source /opt/resultats-bf/venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r /opt/resultats-bf/app/requirements.txt

# 5. Variables d'environnement pour la base de données
echo "Configuration des variables d'environnement..."
cat > /opt/resultats-bf/.env << EOF
DB_HOST=192.168.63.31
DB_PORT=5432
DB_NAME=resultats_bf
DB_USER=resultats_user
DB_PASSWORD=changeme_password
EOF

# 6. Créer un service systemd pour démarrer automatiquement
echo "Création du service systemd..."
cat > /etc/systemd/system/resultats-bf.service << 'EOF'
[Unit]
Description=RESULTATS-BF FastAPI Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/resultats-bf/app
Environment="PATH=/opt/resultats-bf/venv/bin"
EnvironmentFile=/opt/resultats-bf/.env
ExecStart=/opt/resultats-bf/venv/bin/python server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# 7. Activer et démarrer le service
echo " Démarrage du service..."
systemctl daemon-reload
systemctl enable resultats-bf
systemctl restart resultats-bf

# 8. Attendre que le service démarre
sleep 3

# 9. Vérifier le statut
echo "Statut du service:"
systemctl status resultats-bf --no-pager || true

# 10. Test de santé
echo "Test de l'endpoint /info..."
curl -s http://localhost:3000/info || echo " Service pas encore prêt (normal si BDD pas installée)"

echo "Configuration de $(hostname) terminée !"
echo "Application accessible sur http://$(hostname -I | awk '{print $1}'):3000"
