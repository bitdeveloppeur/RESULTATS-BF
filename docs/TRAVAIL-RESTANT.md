# 📋 TRAVAIL RESTANT - RÉSULTATS-BF

**Progression globale : 70% FAIT ✅ | 30% À FAIRE ⏳**

---

## ✅ CE QUI EST DÉJÀ FAIT (Ne pas refaire !)

- ✅ Infrastructure complète (5 VMs fonctionnelles)
- ✅ Load balancing HAProxy avec health checks
- ✅ Application FastAPI (3 endpoints)
- ✅ Base de données PostgreSQL (50 000 résultats)
- ✅ Réplication streaming bdd1 → bdd2
- ✅ Documentation architecture et guides techniques
- ✅ Tous les scripts de provisioning (lb.sh, app.sh, bdd.sh, replique.sh)
- ✅ Vagrantfile (source unique de vérité)
- ✅ Les 8 exigences obligatoires (R1 à R8)

**En gros : Le "cœur" du projet est terminé et fonctionne !**

---

## ⏳ CE QUI RESTE À FAIRE (30%)

### 🎯 PARTIE 1 : VALIDATION DES SCÉNARIOS (Obligatoire)
**Temps estimé : 2-3 heures**  
**Difficulté : ⭐ Facile**

Il faut **prouver** que notre infrastructure fonctionne en testant 6 scénarios.

#### 📌 Scénario V1 : Distribution de Charge (OBLIGATOIRE)
**But** : Prouver que HAProxy répartit bien les requêtes entre app1 et app2

**À faire** :
1. Lancer plusieurs requêtes vers `http://localhost:8080/info`
2. Vérifier que les réponses alternent entre app1 et app2
3. Capturer les logs HAProxy qui montrent la distribution
4. Faire des **screenshots** ou copier-coller les résultats dans un fichier

**Commandes** :
```powershell
# Test distribution
for ($i=1; $i -le 10; $i++) { 
    Write-Host "Requête $i :" -NoNewline
    (curl http://localhost:8080/info -UseBasicParsing).Content 
}

# Logs HAProxy (dans une autre fenêtre)
vagrant ssh lb1 -c "sudo tail -f /var/log/haproxy.log"
```

**Livrable** : 
- Screenshots montrant alternance app1/app2
- OU fichier texte avec les résultats

---

#### 📌 Scénario V2 : Panne Serveur Application (OBLIGATOIRE)
**But** : Prouver que si app1 tombe, HAProxy continue avec app2 seulement

**À faire** :
1. Arrêter app1 : `vagrant halt app1`
2. Faire 5 requêtes → doivent TOUTES aller sur app2
3. Vérifier dans les logs que app1 est détecté comme DOWN
4. Redémarrer app1 : `vagrant up app1`
5. Vérifier que la distribution reprend (app1 et app2)

**Commandes** :
```powershell
# 1. Arrêter app1
vagrant halt app1

# 2. Tester (doit aller que sur app2)
for ($i=1; $i -le 5; $i++) { 
    (curl http://localhost:8080/info -UseBasicParsing).Content 
}

# 3. Logs HAProxy (voir app1 marqué DOWN)
vagrant ssh lb1 -c "sudo tail -20 /var/log/haproxy.log"

# 4. Redémarrer app1
vagrant up app1

# 5. Attendre 10 secondes, refaire le test
Start-Sleep -Seconds 10
for ($i=1; $i -le 5; $i++) { 
    (curl http://localhost:8080/info -UseBasicParsing).Content 
}
```

**Livrable** :
- Screenshots avant/pendant/après la panne
- Logs HAProxy montrant app1 DOWN puis UP

---

#### 📌 Scénario V4 : Réplication Base de Données (OBLIGATOIRE)
**But** : Prouver que bdd2 réplique bien les données de bdd1

**À faire** :
1. Vérifier que bdd2 est en mode réplication
2. Comparer les données sur bdd1 et bdd2 (doivent être identiques)
3. (Bonus) Ajouter une ligne sur bdd1 et vérifier qu'elle apparaît sur bdd2

**Commandes** :
```powershell
# 1. Vérifier que bdd2 est en réplication
vagrant ssh bdd2 -c "sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"
# Doit retourner 't' (true)

# 2. Comparer les 5 premiers résultats sur bdd1
vagrant ssh bdd1 -c "sudo -u postgres psql resultats_bf -c 'SELECT * FROM resultats LIMIT 5;'"

# 3. Même chose sur bdd2
vagrant ssh bdd2 -c "sudo -u postgres psql resultats_bf -c 'SELECT * FROM resultats LIMIT 5;'"
# Les résultats doivent être IDENTIQUES

# 4. Compter le nombre de lignes
vagrant ssh bdd1 -c "sudo -u postgres psql resultats_bf -c 'SELECT COUNT(*) FROM resultats;'"
vagrant ssh bdd2 -c "sudo -u postgres psql resultats_bf -c 'SELECT COUNT(*) FROM resultats;'"
# Doit être 50000 sur les deux
```

**Livrable** :
- Screenshots montrant données identiques sur bdd1 et bdd2
- Résultat de `pg_is_in_recovery()` montrant 't'

---

#### 📌 Scénarios V3, V5, V6 (Optionnels - Bonus)
**Note** : Le PDF demande 6 scénarios mais 3 sont obligatoires. Faire V3, V5 ou V6 donne des points bonus.

**V3** : Panne load balancer (tester accès direct aux apps)  
**V5** : Bascule base de données (promouvoir bdd2 en primaire)  
**V6** : Restauration complète (`vagrant destroy` puis `vagrant up`)

**Recommandation** : Faire V6 (restauration) car c'est facile et ça prouve l'Infrastructure as Code.

---

### 🎯 PARTIE 2 : RÔLE INGÉNIEUR TESTS (Obligatoire)
**Temps estimé : 3-4 heures**  
**Difficulté : ⭐⭐ Moyen**

Il faut créer des **tests automatisés** pour l'application FastAPI.

#### Ce qu'il faut faire :

1. **Choisir un framework de tests** : `pytest` (recommandé)

2. **Créer des tests unitaires** dans `tests/` :
   - `test_info.py` - Tester l'endpoint GET /info
   - `test_sante.py` - Tester l'endpoint GET /sante
   - `test_resultat.py` - Tester l'endpoint GET /resultat

3. **Exemples de tests** :
   ```python
   def test_info_retourne_200():
       # Tester que /info retourne code 200
   
   def test_sante_database_connected():
       # Tester que /sante dit "connected"
   
   def test_resultat_matricule_valide():
       # Tester qu'un matricule existant retourne des données
   
   def test_resultat_matricule_invalide():
       # Tester qu'un matricule inexistant retourne 404
   ```

4. **Ajouter dans README** : Comment lancer les tests
   ```bash
   pip install pytest
   pytest tests/
   ```

**Fichiers à créer** :
- `tests/test_info.py`
- `tests/test_sante.py`
- `tests/test_resultat.py`
- `tests/conftest.py` (configuration pytest)
- `requirements-dev.txt` (dépendances de test)

**Livrable** :
- Dossier `tests/` avec les fichiers de tests
- Screenshot des tests qui passent (tous verts ✅)
- Section dans la documentation finale sur les tests

---

### 🎯 PARTIE 3 : EXTENSIONS (Choisir 2 parmi 4)
**Temps estimé : 6-10 heures (selon extension)**  
**Difficulté : ⭐⭐⭐ Variable**

Le PDF demande de choisir **2 extensions** parmi 4 proposées.

---

#### 🔐 Extension E1 : HTTPS avec Certificat Auto-Signé
**Temps estimé : 2 heures**  
**Difficulté : ⭐⭐ Moyen**

**But** : Sécuriser les communications avec HTTPS

**À faire** :
1. Générer un certificat SSL auto-signé sur lb1
2. Modifier la config HAProxy pour écouter en HTTPS (port 443)
3. Modifier Vagrantfile pour forward le port 8443
4. Tester avec `https://localhost:8443/info`

**Commandes** :
```bash
# Sur lb1
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/haproxy.key \
  -out /etc/ssl/certs/haproxy.crt
  
# Combiner cert + key
cat /etc/ssl/certs/haproxy.crt /etc/ssl/private/haproxy.key > /etc/haproxy/haproxy.pem
```

**Modifier HAProxy** :
```
frontend https_front
    bind *:443 ssl crt /etc/haproxy/haproxy.pem
    default_backend app_servers
```

**Livrable** :
- Script `scripts/https.sh` ou modification de `lb.sh`
- Screenshot montrant `https://localhost:8443/info` qui fonctionne
- Documentation de l'implémentation

---

#### 🌐 Extension E2 : Interface Web (HTML + Bootstrap)
**Temps estimé : 3-4 heures**  
**Difficulté : ⭐⭐ Moyen**

**But** : Créer une belle page web pour consulter les résultats

**À faire** :
1. Créer un dossier `web/` avec :
   - `index.html` - Formulaire pour entrer le matricule
   - `style.css` - Styles (ou utiliser Bootstrap CDN)
   - `script.js` - JavaScript pour appeler l'API

2. Exemple de formulaire :
   ```html
   <input type="text" placeholder="Matricule (ex: 000001)">
   <button>Rechercher</button>
   <div id="resultat"></div>
   ```

3. JavaScript pour appeler l'API :
   ```javascript
   fetch(`http://localhost:8080/resultat?matricule=${matricule}`)
     .then(response => response.json())
     .then(data => afficherResultat(data));
   ```

4. Configurer HAProxy pour servir les fichiers statiques (OU créer un nginx)

**Livrable** :
- Dossier `web/` avec HTML/CSS/JS
- Screenshot de l'interface web fonctionnelle
- Documentation de l'interface

---

#### 🔴 Extension E3 : Cache Redis
**Temps estimé : 4-5 heures**  
**Difficulté : ⭐⭐⭐ Difficile**

**But** : Améliorer les performances avec un cache

**À faire** :
1. Ajouter une 6ème VM `redis1` (IP 192.168.63.41)
2. Script `scripts/redis.sh` pour installer Redis
3. Modifier `app/database.py` :
   - Avant de chercher en BDD, vérifier si c'est dans Redis
   - Si oui, retourner depuis Redis (rapide)
   - Si non, chercher en BDD et mettre en cache (TTL 5 min)
4. Ajouter `redis` dans `requirements.txt`
5. Mesurer l'amélioration (avant/après cache)

**Livrable** :
- VM redis1 opérationnelle
- Code modifié avec gestion du cache
- Benchmark montrant amélioration des performances
- Documentation de l'implémentation

---

#### 📊 Extension E4 : Monitoring Prometheus + Grafana
**Temps estimé : 5-6 heures**  
**Difficulté : ⭐⭐⭐⭐ Difficile**

**But** : Surveiller la santé du système

**À faire** :
1. Ajouter VM `monitoring1` (IP 192.168.63.51)
2. Installer Prometheus + Grafana
3. Configurer exporters :
   - HAProxy exporter (métriques load balancer)
   - PostgreSQL exporter (métriques BDD)
4. Créer un dashboard Grafana avec :
   - Nombre de requêtes par seconde
   - Temps de réponse moyen
   - État des serveurs (UP/DOWN)
   - Charge CPU/RAM
5. Accès Grafana sur `http://localhost:3000`

**Livrable** :
- VM monitoring1 opérationnelle
- Dashboard Grafana configuré
- Screenshots du dashboard
- Documentation de la configuration

---

### 🎯 RECOMMANDATION EXTENSIONS

**Si vous avez peu de temps** : E1 (HTTPS) + E2 (Web UI)  
→ Total ~5-6 heures, facile à montrer, valorisant

**Si vous voulez impressionner** : E2 (Web UI) + E4 (Monitoring)  
→ Total ~8-10 heures, très pro, grosse valeur ajoutée

**Si vous aimez l'optimisation** : E1 (HTTPS) + E3 (Redis)  
→ Total ~6-7 heures, focus performance et sécurité

---

### 🎯 PARTIE 4 : DOCUMENTATION FINALE (Obligatoire)
**Temps estimé : 4-6 heures**  
**Difficulté : ⭐⭐ Moyen**

Il faut rédiger un **dossier technique de 10-15 pages** (PDF).

#### Structure recommandée :

1. **Page de garde** (1 page)
   - Titre : "RÉSULTATS-BF - Plateforme de Consultation de Résultats d'Examens"
   - Noms, groupe, date, IBAM

2. **Table des matières** (1 page)

3. **Introduction** (1 page)
   - Contexte du projet
   - Objectifs
   - Technologies choisies

4. **Architecture** (2-3 pages)
   - Schéma réseau (à créer avec draw.io ou autre)
   - Description des 5 VMs
   - Justification des choix techniques (pourquoi HAProxy ? pourquoi FastAPI ?)

5. **Implémentation** (3-4 pages)
   - Rôle Architecte : HAProxy + load balancing
   - Rôle App Engineer : FastAPI + endpoints
   - Rôle Data Engineer : PostgreSQL + réplication
   - Rôle Test Engineer : Tests automatisés

6. **Validation** (2 pages)
   - Résultats des scénarios V1, V2, V4
   - Screenshots des tests

7. **Extensions** (1-2 pages)
   - Description des 2 extensions réalisées
   - Screenshots

8. **Difficultés et Solutions** (1 page)
   - Problèmes rencontrés (on en a résolu 6 !)
   - Comment on les a résolus

9. **Conclusion** (1 page)
   - Bilan du projet
   - Compétences acquises
   - Perspectives d'amélioration

10. **Annexes** (optionnel)
    - Extraits de code importants
    - Logs significatifs

**Outils recommandés** :
- Google Docs / Word pour l'écriture
- Draw.io pour les schémas
- ShareLaTeX si vous voulez du LaTeX (plus pro)

**Livrable** :
- `RESULTATS-BF_Groupe8_Documentation.pdf` (10-15 pages)

---

### 🎯 PARTIE 5 : FINITIONS (Optionnel mais recommandé)
**Temps estimé : 1-2 heures**

#### README.md complet
Créer un README professionnel avec :
- Description du projet
- Prérequis (Vagrant, VirtualBox)
- Installation : `vagrant up`
- Utilisation : commandes de test
- Architecture (petit schéma ASCII)
- Auteurs

#### Vidéo de démonstration (optionnel)
**Durée** : 3-5 minutes  
**Contenu** :
1. Lancer `vagrant up` (accéléré)
2. Tester les 3 endpoints
3. Montrer la distribution de charge
4. Montrer une extension (web UI ou autre)

**Outils** : OBS Studio (gratuit) ou SimpleScreenRecorder

---

## 📅 PLANNING SUGGÉRÉ (7 jours)

| Jour | Tâches | Durée | Qui ? |
|------|--------|-------|-------|
| **Jour 1** | Scénarios V1, V2, V4 | 2h | Personne A |
| **Jour 2** | Rôle Tests (pytest) | 4h | Personne B |
| **Jour 3** | Extension 1 (HTTPS) | 2h | Personne C |
| **Jour 4-5** | Extension 2 (Web UI) | 4h | Personne D |
| **Jour 6** | Rédaction documentation (draft) | 4h | Tous ensemble |
| **Jour 7** | Relecture, finitions, vidéo | 2h | Tous ensemble |

**Total** : ~18 heures réparties sur 7 jours = 2-3h par jour

---

## ✅ CHECKLIST FINALE

Avant de rendre le projet, vérifier que :

### Fonctionnel
- [ ] `vagrant up` fonctionne sans erreur
- [ ] Les 3 endpoints répondent correctement
- [ ] Le load balancing alterne bien
- [ ] La réplication BDD fonctionne
- [ ] Les scénarios V1, V2, V4 sont validés (avec preuves)
- [ ] Les tests automatisés passent tous (vert)
- [ ] Les 2 extensions fonctionnent

### Documentation
- [ ] README.md complet
- [ ] Dossier PDF 10-15 pages rédigé
- [ ] Schémas d'architecture clairs
- [ ] Screenshots de toutes les validations
- [ ] Code commenté

### Git
- [ ] Tous les fichiers commités
- [ ] Messages de commit clairs
- [ ] .gitignore à jour (pas de venv/, .vagrant/)
- [ ] Repo pushé sur GitHub/GitLab
- [ ] README lisible sur la page d'accueil du repo

### Livrable final
- [ ] Code source sur Git
- [ ] PDF documentation
- [ ] (Optionnel) Vidéo démo

---

## 🎯 RÉPARTITION SUGGÉRÉE DU TRAVAIL

### Option 1 : Répartition par rôle (continuer ce qui a été commencé)
- **Architecte** : Scénarios validation + finitions infrastructure
- **App Engineer** : Rôle Tests (pytest)
- **Data Engineer** : Extension Redis (si choisie)
- **Tous** : Documentation (chacun sa partie)

### Option 2 : Répartition par tâche
- **Personne A** : Scénarios V1, V2, V4 (2h)
- **Personne B** : Rôle Tests complet (4h)
- **Personne C** : Extension 1 (2-3h)
- **Personne D** : Extension 2 (3-4h)
- **Tous** : Documentation finale (2h chacun)

### Option 3 : Binômes
- **Binôme 1** : Validation + Tests (6h total)
- **Binôme 2** : Extensions 1+2 (6h total)
- **Tous** : Documentation (4h chacun)

---

## 📞 QUESTIONS À POSER CE SOIR

1. **Deadline** : C'est quand exactement ?
2. **Format livrable** : Git + PDF ? Vidéo obligatoire ?
3. **Qui prend quoi ?** : Répartir selon le planning ci-dessus
4. **Point de suivi** : Quand on se revoit ? (dans 3 jours ?)
5. **Accès au code** : Qui a accès au repo Git ?

---

## 💡 CONSEILS

1. **Commencez par les scénarios** - C'est rapide et ça prouve que ça marche
2. **Faites les tests ensuite** - Ça valide que le code est solide
3. **Choisissez extensions selon vos compétences** - E1+E2 si vous aimez le web
4. **Documentez au fur et à mesure** - Prenez screenshots immédiatement
5. **Faites des commits réguliers** - Avec messages clairs
6. **Testez avant de livrer** - Faites `vagrant destroy && vagrant up` pour vérifier que tout marche

---

## 📊 RÉSUMÉ VISUEL

```
✅ FAIT (70%)
├── Infrastructure (100%)
├── Load balancing (100%)
├── Application FastAPI (100%)
├── Base de données + réplication (100%)
└── Documentation technique (100%)

⏳ À FAIRE (30%)
├── Scénarios validation (0%) → 2h
├── Rôle Tests (0%) → 4h
├── Extension 1 (0%) → 2-5h
├── Extension 2 (0%) → 3-5h
└── Documentation finale (0%) → 4-6h

TOTAL RESTANT : ~15-22 heures
```

---

**Document prêt à partager ! Bonne répartition du travail** 🚀
