# 🎯 Guide de Démonstration - RÉSULTATS-BF

## Pour ta présentation ce soir avec ton équipe

---

## 🚀 Démarrage Rapide (5 minutes)

### 1. Lancer tous les tests
```powershell
powershell -ExecutionPolicy Bypass -File tests/test-simple.ps1
```

**Résultat attendu**: 6-8 tests PASS ✅

---

## 📱 2. Accès aux Interfaces

### A. Frontend Vue.js (Interface Utilisateur)

**Dans ton navigateur, va sur:** http://localhost:8080

**Ce que tu verras:**
- Interface avec le logo et titre "RÉSULTATS-BF"
- Champ de recherche pour entrer un matricule
- Bouton "Rechercher" en vert moutarde (couleurs Burkina Faso 🇧🇫)

**Démonstration:**
1. Entre `000001` dans le champ matricule
2. Clique "Rechercher"
3. **Résultat affiché:**
   ```
   Nom: CANDIDAT_1
   Série: C
   Moyenne: 10.68
   Statut: ✅ ADMIS
   ```

**Autres matricules à tester:**
- `012345` → CANDIDAT_12345
- `025000` → CANDIDAT_25000
- `049999` → CANDIDAT_49999

---

### B. Dashboard HAProxy (Monitoring)

**Dans ton navigateur, va sur:** http://localhost:8080/haproxy?stats

**Login:**
- Utiliser les credentials définis dans `.env` (LB_STATS_USER / LB_STATS_PASSWORD)

**Ce que tu verras:**
- **État des serveurs** (app1, app2): UP 🟢 ou DOWN 🔴
- **Statistiques en temps réel:**
  - Sessions actives
  - Nombre de requêtes traitées
  - Temps de réponse
  - Health checks toutes les 3 secondes
- **Backend**: `app_servers` avec algorithme Round Robin

**Points à montrer:**
- Les 2 serveurs app1 et app2 sont UP 🟢
- Le compteur de requêtes augmente à chaque refresh
- Health check: `GET /api/sante` toutes les 3s

---

### C. Base de Données PostgreSQL

**Se connecter à la BDD:**
```powershell
# Entrer dans bdd1 (primary)
vagrant ssh bdd1

# Connexion PostgreSQL
sudo -u postgres psql resultats_bf
```

**Commandes SQL démo:**
```sql
-- Compter les résultats
SELECT COUNT(*) FROM resultats;
-- Résultat: 50 000

-- Voir un étudiant
SELECT * FROM resultats WHERE matricule = '000001';

-- Statistiques par série
SELECT serie, COUNT(*), ROUND(AVG(moyenne), 2) as moyenne_serie
FROM resultats 
GROUP BY serie;

-- Taux d'admission global
SELECT 
    COUNT(*) FILTER (WHERE admis = true) as admis,
    COUNT(*) FILTER (WHERE admis = false) as recales,
    ROUND(100.0 * COUNT(*) FILTER (WHERE admis = true) / COUNT(*), 2) as taux
FROM resultats;

-- Quitter
\q
exit
```

---

## 🎬 3. Scénarios de Démonstration

### Scénario 1: Fonctionnement Normal ✅

**Objectif:** Montrer que toute l'infrastructure fonctionne

```powershell
# 1. Vérifier l'état des VMs
vagrant status
# → Toutes "running"

# 2. Tester l'API
curl.exe "http://localhost:8080/api/resultat?matricule=000001"

# 3. Ouvrir le frontend
start http://localhost:8080

# 4. Ouvrir le dashboard
start http://localhost:8080/haproxy?stats
```

---

### Scénario 2: Résilience Applicative 🔄

**Objectif:** Démontrer que si app1 tombe, app2 prend le relais automatiquement (R2, R7)

#### Étape 1: État initial
```powershell
curl.exe http://localhost:8080/api/sante
```
**Résultat:** `"hostname":"app1"` ou `"app2"` (Round Robin)

#### Étape 2: Arrêter app1
```powershell
vagrant halt app1
```
⏱️ **Attendre 10 secondes** (pour que le health check détecte la panne)

#### Étape 3: Vérifier que app2 prend le relais
```powershell
curl.exe http://localhost:8080/api/sante
```
**Résultat:** `"hostname":"app2"` ✅

```powershell
# Tester plusieurs fois
for($i=1; $i -le 5; $i++) { 
    curl.exe -s http://localhost:8080/api/sante | Select-String hostname
}
```
**Tous les appels vont vers app2** ✅

#### Étape 4: Dashboard HAProxy
Va sur http://localhost:8080/haproxy?stats

**Tu verras:**
- app1: 🔴 DOWN
- app2: 🟢 UP

#### Étape 5: Redémarrer app1
```powershell
vagrant up app1
```
⏱️ **Attendre 30-40 secondes** (boot + provisioning)

```powershell
# Vérifier
curl.exe http://localhost:8080/api/sante
```
**app1 et app2 alternent à nouveau** ✅

---

### Scénario 3: Haute Disponibilité Load Balancer 🎯

**Objectif:** Démontrer Keepalived/VRRP (E1) - si lb1 tombe, lb2 devient MASTER

#### Étape 1: Vérifier la VIP est sur lb1
```powershell
vagrant ssh lb1 -c "ip addr show eth1 | grep 192.168.63.10"
```
**Résultat:** VIP présente sur lb1 (MASTER)

#### Étape 2: Arrêter lb1 (MASTER)
```powershell
vagrant halt lb1
```

#### Étape 3: VIP bascule automatiquement sur lb2
```powershell
vagrant ssh lb2 -c "ip addr show eth1 | grep 192.168.63.10"
```
**Résultat:** VIP maintenant sur lb2 (devenu MASTER) ✅

#### Étape 4: API toujours accessible
```powershell
curl.exe http://localhost:8080/api/sante
```
**Fonctionne toujours!** ✅

#### Étape 5: Redémarrer lb1
```powershell
vagrant up lb1
```
La VIP reste sur lb2 ou revient sur lb1 (selon la config priority)

---

### Scénario 4: Réplication Base de Données 🗄️

**Objectif:** Montrer la réplication PostgreSQL (R5, R8)

#### Vérifier l'état de la réplication
```powershell
# Sur bdd1 (primary)
vagrant ssh bdd1 -c "sudo -u postgres psql -c 'SELECT client_addr, state, sync_state FROM pg_stat_replication;'"
```

**Résultat:**
```
  client_addr   |   state   | sync_state 
----------------+-----------+------------
 192.168.63.32 | streaming | async
```
✅ **bdd2 est bien en réplication**

#### Test d'insertion (optionnel)
```powershell
# Ajouter un résultat sur bdd1
vagrant ssh bdd1 -c "sudo -u postgres psql resultats_bf -c \"INSERT INTO resultats VALUES ('TEST01', 'DEMO_TEST', 'C', 15.5, true);\""

# Vérifier sur bdd2 qu'il a été répliqué
vagrant ssh bdd2 -c "sudo -u postgres psql resultats_bf -c \"SELECT * FROM resultats WHERE matricule='TEST01';\""
```

**Résultat:** La donnée apparaît sur bdd2 ✅

#### Nettoyage
```powershell
vagrant ssh bdd1 -c "sudo -u postgres psql resultats_bf -c \"DELETE FROM resultats WHERE matricule='TEST01';\""
```

---

### Scénario 5: Load Balancing Round Robin 🔄

**Objectif:** Montrer que les requêtes alternent entre app1 et app2 (R6)

```powershell
# Faire 10 requêtes et observer l'alternance
for($i=1; $i -le 10; $i++) { 
    $hostname = (curl.exe -s http://localhost:8080/api/sante | ConvertFrom-Json).hostname
    Write-Host "Requête $i → $hostname"
}
```

**Résultat attendu:**
```
Requête 1 → app1
Requête 2 → app2
Requête 3 → app1
Requête 4 → app2
Requête 5 → app1
...
```
✅ **Alternance parfaite (Round Robin)**

---

## 📋 4. Checklist Présentation

Avant de commencer, vérifie:

- [ ] Toutes les VMs sont running: `vagrant status`
- [ ] Frontend accessible: http://localhost:8080 ✅
- [ ] Dashboard accessible: http://localhost:8080/haproxy?stats ✅
- [ ] API fonctionne: `curl.exe http://localhost:8080/api/sante` ✅
- [ ] 50 000 résultats en BDD ✅
- [ ] VIP active sur lb1 ou lb2 ✅

---

## 📊 5. Points Clés à Présenter

### Requirements Satisfaits (R1-R8)

✅ **R1**: IaC avec Vagrant (source unique de vérité)  
✅ **R2**: 6 VMs (bdd1, bdd2, app1, app2, lb1, lb2)  
✅ **R3**: 50 000 étudiants générés automatiquement  
✅ **R4**: API REST FastAPI (modulaire)  
✅ **R5**: Réplication PostgreSQL streaming asynchrone  
✅ **R6**: Load balancing HAProxy (Round Robin)  
✅ **R7**: Health checks toutes les 3s (fall 2, rise 2)  
✅ **R8**: Tolérance aux pannes (app et lb)

### Extensions Intégrées

✅ **E1**: HTTPS/HA avec Keepalived (VIP 192.168.63.10, VRRP)  
✅ **E2**: Interface Vue.js (thème vert moutarde 🇧🇫)  
✅ **E4**: Rolling Update (config HAProxy)

### Architecture

```
Internet
    ↓
VIP 192.168.63.10 (Keepalived VRRP)
    ↓
┌─────────────────┬─────────────────┐
│  lb1 (MASTER)   │  lb2 (BACKUP)   │
│   HAProxy       │   HAProxy       │
│  192.168.63.11  │  192.168.63.12  │
└────────┬────────┴────────┬─────────┘
         │ Round Robin     │
    ┌────┴─────────────────┴────┐
    │                           │
┌───▼─────────┐         ┌───────▼───┐
│    app1     │         │    app2   │
│  FastAPI    │         │  FastAPI  │
│192.168.63.21│         │192.168.63.22│
└──────┬──────┘         └──────┬────┘
       │                       │
       └───────────┬───────────┘
                   │
        ┌──────────▼──────────┐
        │  bdd1 (Primary)     │
        │   PostgreSQL        │
        │   192.168.63.31     │
        └──────────┬──────────┘
                   │ Streaming
        ┌──────────▼──────────┐
        │  bdd2 (Replica)     │
        │   PostgreSQL        │
        │   192.168.63.32     │
        └─────────────────────┘
```

---

## 🆘 6. Dépannage Rapide

### Problème: Une VM ne démarre pas
```powershell
vagrant reload <vm> --provision
```

### Problème: Frontend ne s'affiche pas
```powershell
# Vérifier HAProxy
vagrant ssh lb1 -c "sudo systemctl status haproxy"

# Relancer HAProxy
vagrant ssh lb1 -c "sudo systemctl restart haproxy"
vagrant ssh lb2 -c "sudo systemctl restart haproxy"
```

### Problème: API retourne 503
```powershell
# Vérifier les apps
vagrant ssh app1 -c "sudo systemctl status resultats-bf"
vagrant ssh app2 -c "sudo systemctl status resultats-bf"

# Voir les logs
vagrant ssh app1 -c "sudo journalctl -u resultats-bf -n 50"
```

### Problème: BDD ne répond pas
```powershell
vagrant ssh bdd1 -c "sudo systemctl status postgresql"
vagrant ssh bdd1 -c "sudo systemctl restart postgresql"
```

### Tout redémarrer (solution ultime)
```powershell
vagrant halt
vagrant up
```
⏱️ **5-8 minutes** pour tout redémarrer

---

## 🎓 7. Commandes Utiles pour Questions

### Combien de VMs?
```powershell
vagrant status
# → 6 VMs
```

### Combien d'étudiants?
```powershell
vagrant ssh bdd1 -c "sudo -u postgres psql resultats_bf -c 'SELECT COUNT(*) FROM resultats;'"
# → 50 000
```

### Quelle techno pour l'API?
```
FastAPI (Python)
Structure modulaire: app/routes/*.py
```

### Quelle techno pour le frontend?
```
Vue.js 3 + vanilla CSS
Thème vert moutarde (#6B8E23) - couleurs Burkina Faso
```

### Comment fonctionne la HA?
```
Keepalived + VRRP
VIP flottante: 192.168.63.10
lb1 = MASTER (priority 101)
lb2 = BACKUP (priority 100)
Si lb1 tombe → lb2 devient MASTER automatiquement
```

### Algorithme load balancing?
```
Round Robin
Requêtes alternent entre app1 et app2
Health check: GET /api/sante toutes les 3s
```

---

## ✨ 8. Conclusion

**Points forts à souligner:**

1. **Infrastructure as Code** → reproductible à 100%
2. **Haute disponibilité** → tolérance aux pannes (apps + LB + BDD)
3. **Scalabilité** → facile d'ajouter app3, app4, etc.
4. **Monitoring** → dashboard HAProxy temps réel
5. **Extensions** → E1 (HA), E2 (Vue.js), E4 (Rolling Update)
6. **DevOps complet** → 4 rôles (architecte, app, data, test)

**Commande magique pour impressionner:**
```powershell
# Tout détruire et recréer en 8 minutes
vagrant destroy -f
vagrant up
```
→ Infrastructure complète reproductible! 🚀

---

**Bon courage pour ta présentation! 💪**
