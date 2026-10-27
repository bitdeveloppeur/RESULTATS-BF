# RÉSULTATS-BF 🇧🇫

Plateforme résiliente et scalable de consultation de résultats d'examens.

**Projet académique** - Master 1 Informatique - Module DevOps et infrastructures reproductibles  
**Université Joseph Ki Zerbo - IBAM**  
**Groupe 16** - Réseau 192.168.63.0/24

---

## Accès Rapide

| Service | URL | Login |
|---------|-----|-------|
| **Frontend Vue.js** | http://localhost:8080 | - |
| **Dashboard HAProxy** | http://localhost:8080/haproxy?stats | Voir `.env` (LB_STATS_USER / LB_STATS_PASSWORD) |
| **🔧 API Health** | http://localhost:8080/api/sante | - |
| **🔧 API Résultat** | http://localhost:8080/api/resultat?matricule=000001 | - |

### Tests

#### Tests rapides
```powershell
# Tests de base (2 minutes)
powershell -ExecutionPolicy Bypass -File tests/test-simple.ps1
```

#### Suite complète (tests unitaires + intégration)
```powershell
# Tous les tests avec scénarios V1-V6 (10 minutes)
powershell -ExecutionPolicy Bypass -File tests/run-all-tests.ps1
```

### Documentation

| Document | Description |
|----------|-------------|
| **[ACCES-RAPIDE.md](ACCES-RAPIDE.md)** | URLs, commandes essentielles, checklist |
| **[docs/GUIDE-ACCES.md](docs/GUIDE-ACCES.md)** | Guide complet d'accès (frontend, BDD, dashboard, API) |
| **[docs/GUIDE-DEMONSTRATION.md](docs/GUIDE-DEMONSTRATION.md)** | Scénarios de démonstration V1-V6 pour la soutenance |
| **[docs/TESTS.md](docs/TESTS.md)** | Documentation des tests unitaires et d'intégration |
| **[docs/architecture.md](docs/architecture.md)** | Architecture technique détaillée |

---

##  Description

Infrastructure complète pour gérer la publication de résultats d'examens avec deux exigences non fonctionnelles critiques :

- **Résilience** : La panne d'une machine ne doit pas interrompre le service
- **Scalabilité** : Absorber davantage de trafic en ajoutant des machines, sans réécrire la configuration

---

##  Architecture

### Machines virtuelles (socle obligatoire)

| Machine | Rôle | Adresse | RAM | Statut |
|---------|------|---------|-----|--------|
| **bdd1** | Base de données primaire (lecture + écriture) | 192.168.63.31 | 768 Mo |  Obligatoire |
| **bdd2** | Réplique en flux, promouvable | 192.168.63.32 | 768 Mo |  Obligatoire |
| **app1...appN** | Serveurs applicatifs sans état (N ≥ 2) | 192.168.63.21+ | 512 Mo |  Obligatoire |
| **lb1** | Répartiteur de charge actif (HAProxy) | 192.168.63.11 | 512 Mo | Obligatoire |

**Mémoire totale requise** : ~3 Go (socle obligatoire avec 2 serveurs applicatifs)

### Endpoints de l'application

| Endpoint | Description |
|----------|-------------|
| `GET /resultat?matricule=XXX` | Renvoie le résultat du candidat (JSON) |
| `GET /sante` | Sonde de santé pour le load balancer (200 ou 503) |
| `GET /info` | Renvoie le hostname du serveur (pour tester la répartition) |

---

## Installation et utilisation

### Prérequis

- [VirtualBox](https://www.virtualbox.org/) (≥ 6.1.28)
- [Vagrant](https://www.vagrantup.com/) (≥ 2.3)
- 8 Go de RAM minimum
- 20 Go d'espace disque

### Configuration initiale

1. **Cloner le dépôt**
   ```powershell
   git clone https://github.com/bitdeveloppeur/RESULTATS-BF.git
   cd RESULTATS-BF
   ```

2. **Configurer les variables d'environnement**
   ```powershell
   cp .env.exemple .env
   ```
   **Important** : Modifier `.env` avec vos propres mots de passe (jamais commiter `.env` !)

3. **Démarrer l'infrastructure complète**
   ```powershell
   vagrant up
   ```

4. **Accéder à l'application**
   - Ouvrir votre navigateur : http://localhost:8080

### Commandes utiles

```powershell
# Démarrer avec un nombre différent de serveurs applicatifs
$env:NB_APP=4; vagrant up

# Voir le statut des machines
vagrant status

# Se connecter à une machine
vagrant ssh bdd1

# Arrêter toutes les machines
vagrant halt

# Redémarrer et reprovisioner
vagrant reload --provision

# Détruire et recréer (test de reconstruction intégrale - R1)
vagrant destroy -f
vagrant up

# Tester l'idempotence (R2)
vagrant provision
vagrant provision  # doit être identique
```

---

## Scénarios de validation

### V1 - Répartition de charge
```powershell
# 20 appels successifs à /info
for ($i=1; $i -le 20; $i++) { 
    curl http://localhost:8080/info 
}
```
**Attendu** : Les N serveurs apparaissent tour à tour

### V2 - Panne d'un serveur applicatif
```powershell
# Pendant un test de charge
vagrant halt app1
```
**Attendu** : Le service reste disponible ; plus aucune erreur au-delà de 5 secondes

### V3 - Montée en charge
```powershell
# Avec 2 serveurs
ab -n 2000 -c 50 http://localhost:8080/resultat?matricule=12345

# Avec 4 serveurs
$env:NB_APP=4; vagrant up
ab -n 2000 -c 50 http://localhost:8080/resultat?matricule=12345
```
**Attendu** : Le débit augmente avec le nombre de serveurs

### V4 - Panne de la base primaire
```powershell
vagrant halt bdd1
curl http://localhost:8080/sante
```
**Attendu** : Retourne 503 (jamais une page blanche)

### V5 - Reconstruction intégrale
```powershell
vagrant destroy -f
vagrant up
```
**Attendu** : Plateforme fonctionnelle sans intervention manuelle

---

##  Structure du projet

```
RESULTATS-BF/
├── Vagrantfile              # Configuration infrastructure
├── .env.exemple             # Template des variables d'environnement
├── .gitattributes           # Gestion des fins de ligne (CRLF/LF)
├── .gitignore               # Fichiers à ne pas versionner
├── README.md                # Ce fichier
├── config/
│   └── noeuds.yml          # Généré automatiquement (source unique de vérité)
├── scripts/                 # Scripts de provisionnement (Semaine 2)
│   ├── bdd.sh              # Configuration PostgreSQL primaire
│   ├── replique.sh         # Configuration réplication
│   ├── app.sh              # Configuration serveur applicatif
│   └── lb.sh               # Configuration HAProxy
├── app/                     # Application web (Semaine 2)
│   └── server.py           # Serveur applicatif Python
└── docs/                    # Documentation et dossier
    └── architecture.md     # Schéma et justifications
```

---

## Exigences du projet

### Socle obligatoire (8 exigences)

- **R1** - Reconstruction intégrale (`vagrant destroy -f && vagrant up`)
- **R2** - Idempotence (provision rejouable sans modification)
-  **R3** - Nombre de serveurs paramétrable (variable `NB_APP`)
-  **R4** - Sonde de santé fonctionnelle (retrait serveur défaillant < 5s)
-  **R5** - Réplication PostgreSQL (bdd2 réplique de bdd1)
-  **R6** - Procédure de bascule documentée et exécutable
-  **R7** - Aucun secret en clair (`.env` non versionné)
-  **R8** - Trafic interne sur réseau privé uniquement

### Extensions (minimum 2 à choisir)

-  **E1** - Répartiteur redondant (lb2 + keepalived + VRRP)
-  **E2** - Observabilité (Prometheus + Grafana + node_exporter)
-  **E3** - Cache Redis devant la base
- **E4** - Déploiement sans coupure (rolling update)

---

##  Pièges connus

1. **Service sur 127.0.0.1** → Écouter sur `0.0.0.0` pour être joignable
2. **Provisionnement avec `>>`** → Vérifier l'idempotence (pas de doublons)
3. **Données PostgreSQL dans dossier synchronisé** → Utiliser `/var/lib/postgresql`
4. **Ordre de démarrage** → La base doit être prête avant les apps
5. **Fins de ligne CRLF** → Déjà géré par `.gitattributes` 
6. **Sonde de santé non configurée** → Vérifier la config HAProxy

---

## Ressources




