# 📋 Documentation des Tests - RÉSULTATS-BF

## Vue d'ensemble

Le projet comprend **deux niveaux de tests** :
1. **Tests unitaires** : Vérifient chaque composant individuellement
2. **Tests d'intégration** : Valident les scénarios bout-en-bout (V1-V6)

---

## 🧪 Tests Unitaires

### Description
Les tests unitaires vérifient que chaque composant fonctionne correctement de manière isolée.

### Organisation

```
tests/unit/
├── test-infrastructure.ps1  # VMs, services, réseau
├── test-api.ps1             # Endpoints FastAPI
└── test-database.ps1        # PostgreSQL, données
```

### Exécution

#### Tous les tests unitaires
```powershell
# Infrastructure
powershell -ExecutionPolicy Bypass -File tests/unit/test-infrastructure.ps1

# API
powershell -ExecutionPolicy Bypass -File tests/unit/test-api.ps1

# Base de données
powershell -ExecutionPolicy Bypass -File tests/unit/test-database.ps1
```

### Couverture des tests unitaires

#### 1. Infrastructure (`test-infrastructure.ps1`)
- ✅ État des 6 VMs (running/stopped)
- ✅ Services HAProxy actifs sur lb1 et lb2
- ✅ Services Keepalived actifs (VRRP)
- ✅ VIP 192.168.63.10 active
- ✅ Services FastAPI actifs sur app1 et app2
- ✅ Ports réseau ouverts (80, 3000, 5432)
- ✅ Fichiers de configuration présents

**Résultat attendu:** ~14 tests PASS

#### 2. API (`test-api.ps1`)
- ✅ Endpoint root `/` retourne HTML valide
- ✅ Endpoint `/api/sante` retourne status healthy
- ✅ Connexion base de données OK
- ✅ Hostname valide (app1 ou app2)
- ✅ Endpoint `/api/resultat?matricule=X` retourne données
- ✅ Structure JSON valide (matricule, nom, série, moyenne, admis)
- ✅ Code HTTP 404 pour matricule inexistant
- ✅ Temps de réponse < 500ms

**Résultat attendu:** ~10 tests PASS

#### 3. Base de données (`test-database.ps1`)
- ✅ Service PostgreSQL actif
- ✅ Base `resultats_bf` existe
- ✅ Table `resultats` existe
- ✅ 50 000 lignes en base
- ✅ Colonnes requises présentes
- ✅ Séries valides (A, C, D)
- ✅ Moyennes dans [0, 20]
- ✅ Réplication configurée

**Résultat attendu:** ~8 tests PASS

---

## 🔗 Tests d'Intégration

### Description
Les tests d'intégration valident les **6 scénarios de validation (V1-V6)** demandés dans le cahier des charges.

### Organisation

```
tests/integration/
├── test-scenarios.ps1       # Scénarios V1-V6 automatisés
└── rapport-YYYY-MM-DD.txt   # Rapports générés
```

### Exécution

```powershell
powershell -ExecutionPolicy Bypass -File tests/integration/test-scenarios.ps1
```

⚠️ **Attention:** Les tests d'intégration :
- Modifient l'état de l'infrastructure
- Arrêtent/redémarrent des VMs
- Prennent 5-10 minutes
- Génèrent un rapport automatique

### Scénarios testés

#### V1: Répartition (Load Balancing)
**Test:** 20 appels successifs à `/api/sante`  
**Mesure:** Écart entre serveur le plus et moins sollicité  
**Attendu:** < 20%

**Validation:**
- Les requêtes alternent entre app1 et app2
- Distribution équilibrée (Round Robin)

---

#### V2: Panne d'un serveur applicatif
**Test:** `vagrant halt app1` pendant une charge  
**Mesure:** Nombre de requêtes perdues et durée période dégradée  
**Attendu:** Service reste disponible, pas d'erreur au-delà de 5-10s

**Validation:**
- app2 prend automatiquement le relais
- Health check détecte la panne en 6s (2 checks × 3s)
- Pas de coupure prolongée

---

#### V3: Montée en charge
**Test:** 2000 requêtes avec concurrence de 50  
**Mesure:** Requêtes par seconde  
**Attendu:** Débit augmente avec le nombre de serveurs

**Validation:**
- Infrastructure absorbe la charge
- Pas de timeouts
- Débit > 50 req/s avec N=2

---

#### V4: Panne de la base primaire
**Test:** `vagrant halt bdd1`  
**Mesure:** Temps total de bascule sur bdd2  
**Attendu:** Service renvoie proprement 503, jamais page blanche

**Validation:**
- API retourne erreur HTTP propre (503)
- Pas de "Connection refused"
- Pas de page blanche

---

#### V5: Reconstruction
**Test:** `vagrant destroy -f` puis `vagrant up`  
**Mesure:** Durée totale de reconstruction  
**Attendu:** Plateforme fonctionnelle sans intervention

**Validation:**
- Infrastructure se reconstruit automatiquement
- Toutes les données régénérées (50 000 résultats)
- Services démarrent automatiquement
- Durée: 6-10 minutes

---

#### V6: Panne du répartiteur (Extension E1)
**Test:** `vagrant halt lb1`  
**Mesure:** Temps de reprise après bascule VRRP  
**Attendu:** Service reste joignable à la même adresse

**Validation:**
- VIP 192.168.63.10 bascule sur lb2
- Keepalived détecte la panne < 3s
- API reste accessible
- Pas d'interruption de service

---

## 🚀 Lancer tous les tests

### Script maître

```powershell
powershell -ExecutionPolicy Bypass -File tests/run-all-tests.ps1
```

Ce script :
1. Lance tous les tests unitaires
2. Demande confirmation pour les tests d'intégration
3. Génère un rapport global
4. Indique si l'infrastructure est prête pour la démo

### Sortie attendue

```
==========================================
      RÉSULTATS-BF - SUITE DE TESTS      
==========================================

┌──────────────────────────────────────────┐
│    PHASE 1: TESTS UNITAIRES             │
└──────────────────────────────────────────┘

[1/3] Tests unitaires - Infrastructure...
[PASS] VM bdd1 est running
[PASS] VM bdd2 est running
...
Tests réussis: 14

[2/3] Tests unitaires - API...
[PASS] Endpoint root retourne du HTML valide
...
Tests réussis: 10

[3/3] Tests unitaires - Base de données...
[PASS] PostgreSQL actif sur bdd1
...
Tests réussis: 8

┌──────────────────────────────────────────┐
│    PHASE 2: TESTS D'INTÉGRATION         │
└──────────────────────────────────────────┘

V1: RÉPARTITION
✅ PASS - Écart: 10%

V2: PANNE SERVEUR
✅ PASS - Durée: 6s

...

==========================================
      RAPPORT FINAL - TOUS LES TESTS     
==========================================

🎉 TOUS LES TESTS SONT PASSÉS! ✅

Infrastructure prête pour la démonstration!
```

---

## 📊 Métriques et KPIs

### Performance
- **Temps de réponse API:** < 500ms (moyen: ~50ms)
- **Débit:** > 50 req/s avec 2 serveurs
- **Disponibilité:** 99.9% avec HA

### Résilience
- **Détection panne app:** 6 secondes (2 health checks)
- **Bascule VRRP (VIP):** < 3 secondes
- **Récupération auto:** Oui (health checks)

### Reconstruction
- **Temps total:** 6-10 minutes
- **Intervention manuelle:** 0
- **Taux de succès:** 100%

---

## 🛠️ Troubleshooting

### Test échoue: "VM not running"
```powershell
vagrant up
```

### Test échoue: "API timeout"
```powershell
# Vérifier les services
vagrant ssh app1 -c "sudo systemctl status resultats-bf"
vagrant ssh app2 -c "sudo systemctl status resultats-bf"
```

### Test échoue: "Database connection"
```powershell
# Vérifier PostgreSQL
vagrant ssh bdd1 -c "sudo systemctl status postgresql"
```

### Réinitialiser complètement
```powershell
vagrant destroy -f
vagrant up
powershell tests/run-all-tests.ps1
```

---

## 📝 Rapport de tests

Après chaque exécution des tests d'intégration, un rapport est généré :

```
tests/integration/rapport-2026-10-26_20-30-45.txt
```

Ce rapport contient :
- Statut de chaque scénario (PASS/FAIL/WARN)
- Mesures effectuées
- Détails des résultats

**Utilisez ce rapport pour votre soutenance !**

---

## ✅ Checklist avant démonstration

```powershell
# 1. Lancer tous les tests
powershell tests/run-all-tests.ps1

# 2. Vérifier l'état
vagrant status

# 3. Tester manuellement
curl.exe http://localhost:8080/api/sante

# 4. Ouvrir le dashboard
start http://localhost:8080/haproxy?stats
```

Si tous les tests passent → **Vous êtes prêt pour la démonstration ! 🎉**
