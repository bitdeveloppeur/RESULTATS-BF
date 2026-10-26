# 🗄️ Guide Ingénieur Données

## 🎯 Rôle et responsabilités

L'Ingénieur Données est responsable de :
1. Installation et configuration PostgreSQL
2. Création de la base de données et des tables
3. Génération des données de test (50 000 lignes)
4. Configuration de la réplication streaming (bdd1 → bdd2)
5. Procédure de bascule (failover) de bdd1 vers bdd2

---

## 📊 Architecture de la base de données

### Machines

| Machine | Rôle | IP | Port |
|---------|------|-----|------|
| **bdd1** | Primaire (lecture + écriture) | 192.168.63.31 | 5432 |
| **bdd2** | Réplique (lecture seule) | 192.168.63.32 | 5432 |

### Base de données

- **Nom** : `resultats_bf`
- **Utilisateur** : `resultats_user`
- **Mot de passe** : `changeme_password` (à changer en production !)

### Table `resultats`

```sql
CREATE TABLE resultats (
    id SERIAL PRIMARY KEY,
    matricule VARCHAR(20) UNIQUE NOT NULL,
    nom VARCHAR(100) NOT NULL,
    serie VARCHAR(10) NOT NULL,         -- A, C, D, S
    moyenne DECIMAL(4,2) NOT NULL,       -- Entre 0 et 20
    admis BOOLEAN NOT NULL,              -- true/false
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 🔧 Script `bdd.sh` - Explication

### Étape 1 : Installation PostgreSQL
```bash
apt-get install -y postgresql postgresql-contrib
```
Installe PostgreSQL 14 depuis les dépôts Ubuntu.

### Étape 2 : Création utilisateur et base
```sql
CREATE USER resultats_user WITH PASSWORD 'changeme_password';
CREATE DATABASE resultats_bf OWNER resultats_user;
```

### Étape 3 : Génération des données
```sql
INSERT INTO resultats (matricule, nom, serie, moyenne, admis)
SELECT
    LPAD(i::TEXT, 6, '0') AS matricule,  -- '000001', '000002', ...
    'CANDIDAT_' || i AS nom,
    CASE (i % 4)
        WHEN 0 THEN 'A'
        WHEN 1 THEN 'C'
        WHEN 2 THEN 'D'
        ELSE 'S'
    END AS serie,
    ROUND((RANDOM() * 10 + 5)::NUMERIC, 2) AS moyenne,  -- Entre 5 et 15
    CASE WHEN RANDOM() > 0.3 THEN true ELSE false END AS admis  -- 70% admis
FROM generate_series(1, 50000) AS i;
```

**Explication** :
- `generate_series(1, 50000)` : Génère les nombres de 1 à 50 000
- `LPAD(i::TEXT, 6, '0')` : Pad avec des zéros (ex: 1 → '000001')
- `i % 4` : Modulo pour alterner les séries (A, C, D, S)
- `RANDOM() * 10 + 5` : Moyenne entre 5 et 15
- `RANDOM() > 0.3` : 70% de chance d'être admis

### Étape 4 : Configuration réseau
```bash
# Écouter sur toutes les interfaces (pas seulement localhost)
listen_addresses = '*'

# Autoriser les connexions depuis le réseau privé
host resultats_bf resultats_user 192.168.63.0/24 md5
```

**Pourquoi ?**
- Par défaut, PostgreSQL n'écoute que sur `localhost`
- Les serveurs app (192.168.63.21, .22, ...) ne pourraient pas se connecter
- On autorise uniquement le réseau privé `192.168.63.0/24`

---

## 🧪 Tests et validation

### Test 1 : Connexion depuis l'hôte bdd1
```bash
sudo -u postgres psql -d resultats_bf -c "SELECT COUNT(*) FROM resultats;"
```
**Résultat attendu** : `50000`

### Test 2 : Connexion depuis un serveur app
```bash
# Depuis app1 (192.168.63.21)
psql -h 192.168.63.31 -U resultats_user -d resultats_bf -c "SELECT COUNT(*) FROM resultats;"
```
**Résultat attendu** : `50000`

### Test 3 : Requête via l'API
```bash
curl http://localhost:8080/resultat?matricule=000001
```
**Résultat attendu** :
```json
{
  "matricule": "000001",
  "nom": "CANDIDAT_1",
  "serie": "C",
  "moyenne": 12.45,
  "admis": true
}
```

---

## 📊 Statistiques des données générées

| Statistique | Valeur approximative |
|-------------|----------------------|
| **Total candidats** | 50 000 |
| **Candidats admis** | ~35 000 (70%) |
| **Moyenne générale** | ~10/20 |
| **Séries** | 25% par série (A, C, D, S) |

---

## 🔐 Sécurité

### ⚠️ Mots de passe en dur (à NE PAS faire en production)

Pour ce projet académique, on utilise des mots de passe simples en dur :
- `changeme_password` pour `resultats_user`

**En production, il faudrait** :
- Utiliser des mots de passe forts générés aléatoirement
- Stocker les secrets dans un gestionnaire (Vault, AWS Secrets Manager)
- Chiffrer les connexions avec SSL/TLS

### ✅ Bonnes pratiques appliquées

1. **Principe du moindre privilège** : `resultats_user` n'a accès qu'à `resultats_bf`
2. **Firewall réseau** : Seul le réseau privé `192.168.63.0/24` peut se connecter
3. **Pas de superuser** : L'application n'utilise pas le compte `postgres`

---

## 🚀 Prochaines étapes

1. ✅ `scripts/bdd.sh` terminé
2. ⏳ `scripts/replique.sh` (réplication streaming)
3. ⏳ Procédure de bascule (failover)
4. ⏳ Tests de résilience (Scénario V4)

---

## 📚 Ressources

- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/14/)
- [Streaming Replication](https://www.postgresql.org/docs/14/warm-standby.html)
- [pg_hba.conf](https://www.postgresql.org/docs/14/auth-pg-hba-conf.html)
