# Procédure de bascule PostgreSQL (Failover)

## Objectif

Promouvoir **bdd2** (réplique) en **primaire** lorsque **bdd1** tombe en panne.

---

## Situation avant bascule

```
bdd1 (primaire)  →  bdd2 (réplique)
192.168.63.31        192.168.63.32
Lecture + Écriture   Lecture seule
      PANNE!            OK
```

## Situation après bascule

```
bdd1 (arrêtée)      bdd2 (promue primaire)
192.168.63.31        192.168.63.32
                    Lecture + Écriture
```

---

## Quand effectuer la bascule ?

**Cas d'usage** :
- bdd1 ne répond plus
- Panne matérielle
- Maintenance planifiée
- Test de résilience (Scénario V4)

**Vérifications avant bascule** :
1. bdd1 est vraiment inaccessible (pas juste lente)
2. bdd2 est synchronisée (pas de lag important)
3. L'application peut pointer vers bdd2

---

##  Procédure de bascule (étape par étape)

### Étape 1 : Se connecter à bdd2

```bash
vagrant ssh bdd2
```

### Étape 2 : Vérifier que bdd2 est en réplication

```bash
sudo -u postgres psql -d resultats_bf -c "SELECT pg_is_in_recovery();"
```

**Résultat attendu** : `t` (true = en mode récupération/réplique)

### Étape 3 : Promouvoir bdd2 en primaire

```bash
sudo -u postgres pg_ctl promote -D /var/lib/postgresql/14/main
```

**OU** :

```bash
sudo -u postgres psql -c "SELECT pg_promote();"
```

### Étape 4 : Vérifier que bdd2 est maintenant primaire

```bash
sudo -u postgres psql -d resultats_bf -c "SELECT pg_is_in_recovery();"
```

**Résultat attendu** : `f` (false = plus en mode récupération, maintenant primaire)

### Étape 5 : Tester l'écriture sur bdd2

```bash
sudo -u postgres psql -d resultats_bf <<EOF
INSERT INTO resultats (matricule, nom, serie, moyenne, admis)
VALUES ('999999', 'TEST_BASCULE', 'S', 12.00, true);

SELECT * FROM resultats WHERE matricule = '999999';
EOF
```

**Si ça marche** : bdd2 est maintenant primaire ! 

### Étape 6 : Reconfigurer l'application pour pointer vers bdd2

**Option A** : Modifier `.env` sur chaque serveur app

```bash
vagrant ssh app1
sudo sed -i 's/DB_HOST=192.168.63.31/DB_HOST=192.168.63.32/' /opt/resultats-bf/.env
sudo systemctl restart resultats-bf
```

**Option B** : Utiliser un script automatisé

```bash
# Depuis l'hôte
for i in 1 2; do
  vagrant ssh app$i -c "
    sudo sed -i 's/DB_HOST=192.168.63.31/DB_HOST=192.168.63.32/' /opt/resultats-bf/.env
    sudo systemctl restart resultats-bf
  "
done
```

### Étape 7 : Vérifier que l'application fonctionne

```bash
curl http://localhost:8080/sante
curl http://localhost:8080/resultat?matricule=000001
```

---

## ⏱️ Temps de bascule attendu

| Étape | Durée |
|-------|-------|
| Détection de la panne | ~5 secondes (sonde /sante) |
| Promotion de bdd2 | ~2 secondes |
| Redémarrage des apps | ~5 secondes |
| **Total** | **~12 secondes** |

**Exigence R6** : Procédure de bascule exécutable et chronométrée 

---

##  Procédure de retour (Failback)

**Quand bdd1 est réparée** et qu'on veut la remettre en primaire :

### Option 1 : bdd1 devient réplique de bdd2

1. Nettoyer bdd1 :
   ```bash
   vagrant ssh bdd1
   sudo systemctl stop postgresql
   sudo rm -rf /var/lib/postgresql/14/main/*
   ```

2. Reconfigurer bdd1 comme réplique de bdd2 :
   ```bash
   sudo -u postgres pg_basebackup \
       -h 192.168.63.32 \
       -D /var/lib/postgresql/14/main \
       -U replication_user \
       -v -P -X stream -R
   ```

3. Redémarrer bdd1 :
   ```bash
   sudo systemctl start postgresql
   ```

Maintenant : **bdd2 (primaire) → bdd1 (réplique)**

### Option 2 : Inverser les rôles (bdd1 redevient primaire)

Refaire une bascule, mais dans l'autre sens !

---

## Script de test de bascule

```bash
#!/bin/bash
# test-bascule.sh

echo "=== Test de bascule bdd1 → bdd2 ==="

# 1. Arrêter bdd1
echo "1. Arrêt de bdd1..."
vagrant halt bdd1

# 2. Vérifier que l'app détecte la panne
echo "2. Test /sante (devrait être 503)..."
curl -s http://localhost:8080/sante

# 3. Promouvoir bdd2
echo "3. Promotion de bdd2..."
vagrant ssh bdd2 -c "sudo -u postgres pg_ctl promote -D /var/lib/postgresql/14/main"

# 4. Reconfigurer les apps
echo "4. Reconfiguration des apps..."
for i in 1 2; do
  vagrant ssh app$i -c "
    sudo sed -i 's/DB_HOST=192.168.63.31/DB_HOST=192.168.63.32/' /opt/resultats-bf/.env
    sudo systemctl restart resultats-bf
  "
done

# 5. Attendre
sleep 5

# 6. Tester
echo "5. Test final..."
curl http://localhost:8080/sante
curl http://localhost:8080/resultat?matricule=000001

echo " Bascule terminée !"
```

---

## Points d'attention

### Split-brain (scénario catastrophe)

**Problème** : Si bdd1 revient en ligne ET que bdd2 est déjà promue, on a **2 primaires** !

**Solution** : S'assurer que bdd1 est bien arrêtée avant de promouvoir bdd2.

### Lag de réplication

Si bdd2 est en retard sur bdd1 :
- Certaines écritures récentes sur bdd1 peuvent être perdues
- Vérifier le lag avant de promouvoir :

```sql
SELECT
    CASE WHEN pg_is_in_recovery() THEN
        EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))
    ELSE
        0
    END AS replication_lag_seconds;
```

---

## Checklist de bascule

- [ ] bdd1 est inaccessible (confirmé)
- [ ] bdd2 est synchronisée (lag < 1 seconde)
- [ ] Promotion de bdd2 effectuée
- [ ] bdd2 accepte les écritures
- [ ] Applications reconfigurées (DB_HOST=192.168.63.32)
- [ ] Applications redémarrées
- [ ] Tests fonctionnels OK (/sante, /resultat)
- [ ] Temps de bascule mesuré et documenté
- [ ] Procédure de retour planifiée

---

## Commandes utiles

```bash
# Vérifier le statut de réplication sur bdd1 (primaire)
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"

# Vérifier le statut sur bdd2 (réplique)
sudo -u postgres psql -d resultats_bf -c "SELECT pg_is_in_recovery();"

# Voir le lag de réplication
sudo -u postgres psql -d resultats_bf -c "
SELECT
    EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) AS lag_seconds;
"

# Promouvoir la réplique
sudo -u postgres pg_ctl promote -D /var/lib/postgresql/14/main
```

---

