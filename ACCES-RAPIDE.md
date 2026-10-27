#  ACCÈS RAPIDE - RÉSULTATS-BF

##  URLs à retenir

| Service | URL | Login |
|---------|-----|-------|
| **Frontend Vue.js** | http://localhost:8080 | - |
| **Dashboard HAProxy** | http://localhost:8080/haproxy?stats | Voir `.env` (LB_STATS_USER / LB_STATS_PASSWORD) |
| **API Health Check** | http://localhost:8080/api/sante | - |
| **API Résultat** | http://localhost:8080/api/resultat?matricule=000001 | - |

---

## Accès SSH aux VMs

```powershell
vagrant ssh lb1      # Load Balancer 1 (MASTER)
vagrant ssh lb2      # Load Balancer 2 (BACKUP)
vagrant ssh app1     # Application 1
vagrant ssh app2     # Application 2
vagrant ssh bdd1     # Base de données 1 (Primary)
vagrant ssh bdd2     # Base de données 2 (Replica)
```

---

##  Base de Données

### Connexion rapide
```powershell
vagrant ssh bdd1
sudo -u postgres psql resultats_bf
```

### Commandes SQL utiles
```sql
-- Compter les résultats
SELECT COUNT(*) FROM resultats;

-- Voir un étudiant
SELECT * FROM resultats WHERE matricule = '000001';

-- Quitter
\q
```

---

## Tests

### Lancer tous les tests
```powershell
powershell -ExecutionPolicy Bypass -File tests/test-simple.ps1
```

### Tests manuels rapides
```powershell
# Test 1: VMs running
vagrant status

# Test 2: Frontend accessible
start http://localhost:8080

# Test 3: API fonctionne
curl.exe "http://localhost:8080/api/resultat?matricule=000001"

# Test 4: Dashboard HAProxy
start http://localhost:8080/haproxy?stats

# Test 5: Base de données (50 000 résultats)
vagrant ssh bdd1 -c "sudo -u postgres psql resultats_bf -c 'SELECT COUNT(*) FROM resultats;'"

# Test 6: VIP Keepalived
vagrant ssh lb1 -c "ip addr show eth1 | grep 192.168.63.10"
```

---

##  Démonstration Scénarios

### Scénario 1: Résilience Applicative
```powershell
# Arrêter app1
vagrant halt app1

# Vérifier que app2 prend le relais
curl.exe http://localhost:8080/api/sante

# Dashboard: app1 DOWN, app2 UP
start http://localhost:8080/haproxy?stats

# Redémarrer app1
vagrant up app1
```

### Scénario 2: Haute Disponibilité LB
```powershell
# Vérifier VIP sur lb1
vagrant ssh lb1 -c "ip addr show eth1 | grep 192.168.63.10"

# Arrêter lb1
vagrant halt lb1

# VIP bascule sur lb2
vagrant ssh lb2 -c "ip addr show eth1 | grep 192.168.63.10"

# API toujours accessible
curl.exe http://localhost:8080/api/sante

# Redémarrer lb1
vagrant up lb1
```

---

## Documentation

| Document | Description |
|----------|-------------|
| `README.md` | Vue d'ensemble du projet |
| `docs/GUIDE-ACCES.md` | Guide complet d'accès à tous les composants |
| `docs/GUIDE-DEMONSTRATION.md` | Guide pour la présentation (scénarios détaillés) |
| `docs/architecture.md` | Architecture technique |
| `docs/RESUME-COMPLET.md` | Résumé complet du projet |

---

##  Commandes de Dépannage

```powershell
# Redémarrer une VM
vagrant reload <vm> --provision

# Voir les logs d'une app
vagrant ssh app1 -c "sudo journalctl -u resultats-bf -n 50"

# Redémarrer HAProxy
vagrant ssh lb1 -c "sudo systemctl restart haproxy"

# Vérifier PostgreSQL
vagrant ssh bdd1 -c "sudo systemctl status postgresql"

# Tout redémarrer proprement
vagrant halt
vagrant up
```

---

## Checklist Présentation

- [ ] `vagrant status` → toutes les VMs "running"
- [ ] http://localhost:8080 → Frontend s'affiche
- [ ] http://localhost:8080/haproxy?stats → Dashboard accessible (credentials dans `.env`)
- [ ] `curl.exe http://localhost:8080/api/sante` → {"status":"healthy"}
- [ ] 50 000 résultats en BDD
- [ ] VIP active (lb1 ou lb2)
- [ ] Tests passent: `powershell tests/test-simple.ps1`

---
