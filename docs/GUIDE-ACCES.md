# 🎯 Guide d'accès - RÉSULTATS-BF

Ce document explique comment accéder à tous les composants de l'infrastructure.

---

## 📱 1. Frontend Vue.js (Interface Web)

### Accès
- **URL**: http://localhost:8080
- **Description**: Interface web pour rechercher les résultats d'un étudiant

### Utilisation
1. Ouvre ton navigateur (Chrome, Firefox, Edge)
2. Va sur `http://localhost:8080`
3. Entre un matricule (exemples: `000001`, `012345`, `025000`)
4. Clique sur "Rechercher"
5. Les résultats s'affichent avec:
   - Nom de l'étudiant
   - Série (A, C, D)
   - Moyenne
   - Statut (Admis/Recalé)

### Exemples de matricules à tester
```
000001 → CANDIDAT_1
012345 → CANDIDAT_12345
025000 → CANDIDAT_25000
049999 → CANDIDAT_49999
```

---

## 🗄️ 2. Base de données PostgreSQL

### Accès en ligne de commande

#### Depuis ton ordinateur (Windows)
```powershell
# Se connecter à bdd1 (primary)
vagrant ssh bdd1

# Une fois dans la VM, se connecter à PostgreSQL
sudo -u postgres psql resultats_bf
```

#### Commandes SQL utiles
```sql
-- Voir toutes les tables
\dt

-- Compter le nombre de résultats
SELECT COUNT(*) FROM resultats;

-- Voir les 10 premiers résultats
SELECT * FROM resultats LIMIT 10;

-- Chercher un étudiant spécifique
SELECT * FROM resultats WHERE matricule = '000001';

-- Voir les étudiants admis
SELECT * FROM resultats WHERE admis = true LIMIT 10;

-- Statistiques par série
SELECT serie, COUNT(*), AVG(moyenne) 
FROM resultats 
GROUP BY serie;

-- Quitter PostgreSQL
\q
```

### Vérifier la réplication
```bash
# Sur bdd1 (primary)
vagrant ssh bdd1 -c "sudo -u postgres psql -c 'SELECT * FROM pg_stat_replication;'"

# Sur bdd2 (replica)
vagrant ssh bdd2 -c "sudo -u postgres psql -c 'SELECT * FROM pg_stat_wal_receiver;'"
```

### Accès avec client GUI (optionnel)

Si tu veux utiliser **pgAdmin** ou **DBeaver** depuis Windows:

1. **Installer pgAdmin** ou **DBeaver**
2. **Forward le port PostgreSQL** (modifie le Vagrantfile):
   ```ruby
   config.vm.define "bdd1" do |bdd1|
     bdd1.vm.network "forwarded_port", guest: 5432, host: 5432
   end
   ```
3. **Redémarre bdd1**: `vagrant reload bdd1`
4. **Connexion**:
   - Host: `localhost`
   - Port: `5432`
   - Database: `resultats_bf`
   - User: `resultats_user`
   - Password: `resultats_password`

---

## 📊 3. Dashboard HAProxy (Monitoring)

### Accès
- **URL**: http://localhost:8080/haproxy?stats
- **Credentials**: Définis dans `.env` (variables LB_STATS_USER et LB_STATS_PASSWORD)

### Ce que tu peux voir
- ✅ **État des serveurs** (app1, app2): UP/DOWN
- 📈 **Métriques en temps réel**:
  - Nombre de requêtes par serveur
  - Temps de réponse moyen
  - Taux d'erreur
  - Sessions actives
- 🔄 **Health checks**: toutes les 3 secondes
- 🎯 **Algorithme**: Round Robin (alternance app1/app2)

### Actions possibles
- **Désactiver un serveur**: tester la résilience
- **Voir les logs**: analyser le trafic
- **Statistiques détaillées**: performances

---

## 🔧 4. API REST (Endpoints)

### Base URL
- **Production**: http://localhost:8080
- **Direct app1**: http://192.168.63.21:3000
- **Direct app2**: http://192.168.63.22:3000

### Endpoints disponibles

#### 1. Health Check
```bash
# Windows PowerShell
curl.exe http://localhost:8080/api/sante

# Réponse
{
  "status": "healthy",
  "database": "connected",
  "hostname": "app1"  # ou "app2"
}
```

#### 2. Résultat étudiant
```bash
# Windows PowerShell
curl.exe "http://localhost:8080/api/resultat?matricule=000001"

# Réponse
{
  "matricule": "000001",
  "nom": "CANDIDAT_1",
  "serie": "C",
  "moyenne": 10.68,
  "admis": true
}
```

#### 3. Informations serveur (root)
```bash
curl.exe http://localhost:8080/

# Réponse
{
  "message": "API RÉSULTATS-BF",
  "version": "1.0",
  "endpoints": ["/api/resultat", "/api/sante"]
}
```

---

## 🖥️ 5. Accès SSH aux VMs

### Se connecter à une VM
```powershell
# Load balancer 1
vagrant ssh lb1

# Load balancer 2
vagrant ssh lb2

# Application 1
vagrant ssh app1

# Application 2
vagrant ssh app2

# Base de données 1 (primary)
vagrant ssh bdd1

# Base de données 2 (replica)
vagrant ssh bdd2
```

### Commandes utiles dans les VMs

#### Sur app1/app2 (serveurs applicatifs)
```bash
# Voir les logs de l'application
sudo journalctl -u resultats-bf -f

# Redémarrer l'application
sudo systemctl restart resultats-bf

# Voir le statut
sudo systemctl status resultats-bf

# Tester l'API localement
curl http://localhost:3000/api/sante
```

#### Sur lb1/lb2 (load balancers)
```bash
# Voir les logs HAProxy
sudo journalctl -u haproxy -f

# Tester la config HAProxy
sudo haproxy -c -f /etc/haproxy/haproxy.cfg

# Redémarrer HAProxy
sudo systemctl restart haproxy

# Voir l'état Keepalived (VIP)
sudo systemctl status keepalived
ip addr show eth1 | grep 192.168.63.10
```

#### Sur bdd1/bdd2 (bases de données)
```bash
# Voir les logs PostgreSQL
sudo journalctl -u postgresql -f

# Redémarrer PostgreSQL
sudo systemctl restart postgresql

# Connexion PostgreSQL
sudo -u postgres psql resultats_bf
```

---

## 🧪 6. Tests automatisés

### Lancer tous les tests
```bash
# Rendre le script exécutable (première fois seulement)
chmod +x tests/test-infrastructure.sh

# Lancer les tests
bash tests/test-infrastructure.sh
```

### Tests manuels rapides

#### Test 1: Frontend accessible
```powershell
curl.exe http://localhost:8080/
```

#### Test 2: API fonctionne
```powershell
curl.exe "http://localhost:8080/api/resultat?matricule=000001"
```

#### Test 3: Base de données (50 000 résultats)
```powershell
vagrant ssh bdd1 -c "sudo -u postgres psql resultats_bf -c 'SELECT COUNT(*) FROM resultats;'"
```

#### Test 4: Réplication active
```powershell
vagrant ssh bdd1 -c "sudo -u postgres psql -c 'SELECT state FROM pg_stat_replication;'"
```

#### Test 5: VIP active (HA)
```powershell
vagrant ssh lb1 -c "ip addr show eth1 | grep 192.168.63.10"
```

#### Test 6: Load balancing fonctionne
```powershell
# Faire 5 requêtes et voir l'alternance app1/app2
for($i=1; $i -le 5; $i++) { 
    curl.exe -s http://localhost:8080/api/sante | Select-String hostname
}
```

---

## 🎬 7. Scénarios de démonstration

### Scénario 1: Fonctionnement normal
```powershell
# 1. Vérifier que tout fonctionne
vagrant status

# 2. Tester l'API
curl.exe "http://localhost:8080/api/resultat?matricule=000001"

# 3. Ouvrir le frontend dans le navigateur
start http://localhost:8080

# 4. Ouvrir le dashboard HAProxy
start http://localhost:8080/haproxy?stats
```

### Scénario 2: Résilience applicative (arrêt app1)
```powershell
# 1. État initial
curl.exe http://localhost:8080/api/sante

# 2. Arrêter app1
vagrant halt app1

# 3. Vérifier que app2 prend le relais
curl.exe http://localhost:8080/api/sante
# → devrait afficher "hostname": "app2"

# 4. Dashboard HAProxy montre app1 DOWN
start http://localhost:8080/haproxy?stats

# 5. Redémarrer app1
vagrant up app1
```

### Scénario 3: Haute disponibilité (arrêt lb1)
```powershell
# 1. VIP sur lb1 initialement
vagrant ssh lb1 -c "ip addr show eth1 | grep 192.168.63.10"

# 2. Arrêter lb1 (MASTER)
vagrant halt lb1

# 3. VIP bascule automatiquement sur lb2
vagrant ssh lb2 -c "ip addr show eth1 | grep 192.168.63.10"

# 4. API toujours accessible
curl.exe http://localhost:8080/api/sante

# 5. Redémarrer lb1
vagrant up lb1
```

### Scénario 4: Réplication base de données
```powershell
# 1. Ajouter un résultat sur bdd1 (primary)
vagrant ssh bdd1 -c "sudo -u postgres psql resultats_bf -c \"INSERT INTO resultats VALUES ('999999', 'TEST_REPLICATION', 'C', 15.5, true);\""

# 2. Vérifier sur bdd2 (replica) - doit apparaître
vagrant ssh bdd2 -c "sudo -u postgres psql resultats_bf -c \"SELECT * FROM resultats WHERE matricule='999999';\""

# 3. Nettoyer
vagrant ssh bdd1 -c "sudo -u postgres psql resultats_bf -c \"DELETE FROM resultats WHERE matricule='999999';\""
```

---

## 🆘 8. Troubleshooting

### Problème: Frontend ne s'affiche pas
```powershell
# Vérifier que HAProxy écoute sur le port 80
vagrant ssh lb1 -c "sudo netstat -tlnp | grep :80"

# Vérifier les logs HAProxy
vagrant ssh lb1 -c "sudo journalctl -u haproxy -n 50"
```

### Problème: API retourne 503 Service Unavailable
```powershell
# Vérifier que les apps sont UP
vagrant ssh app1 -c "sudo systemctl status resultats-bf"
vagrant ssh app2 -c "sudo systemctl status resultats-bf"

# Vérifier la connexion BDD
vagrant ssh app1 -c "curl localhost:3000/api/sante"
```

### Problème: Base de données inaccessible
```powershell
# Vérifier PostgreSQL
vagrant ssh bdd1 -c "sudo systemctl status postgresql"

# Tester connexion
vagrant ssh bdd1 -c "sudo -u postgres psql -c 'SELECT 1;'"
```

### Problème: VIP ne bascule pas
```powershell
# Vérifier Keepalived sur les deux LB
vagrant ssh lb1 -c "sudo systemctl status keepalived"
vagrant ssh lb2 -c "sudo systemctl status keepalived"

# Voir les logs VRRP
vagrant ssh lb1 -c "sudo journalctl -u keepalived -n 50"
```

### Tout redémarrer proprement
```powershell
# Arrêter toutes les VMs
vagrant halt

# Redémarrer toutes les VMs
vagrant up

# Ou redémarrer une seule VM
vagrant reload app1 --provision
```

---

## 📚 9. Ressources supplémentaires

### Documentation du projet
- `README.md` - Vue d'ensemble
- `docs/architecture.md` - Architecture détaillée
- `docs/RESUME-COMPLET.md` - Résumé complet du projet
- `docs/ETAT-PROJET.md` - État du projet

### Fichiers de configuration
- `Vagrantfile` - Configuration des VMs
- `config/noeuds.yml` - Liste des nœuds
- `scripts/` - Scripts de provisioning

### Code source
- `app/` - Application FastAPI
- `web/` - Interface Vue.js
- `tests/` - Scripts de tests

---

**Bon courage pour ta présentation ! 🚀**
