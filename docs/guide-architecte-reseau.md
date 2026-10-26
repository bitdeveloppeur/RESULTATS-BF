# 👷 Guide Architecte Réseau — Expliqué simplement

## 🤔 C'est quoi un Architecte Réseau ?

**En une phrase** : C'est la personne qui décide **comment les machines communiquent entre elles**.

Imagine que tu construis une maison avec plusieurs pièces :
- 🏠 **Architecte bâtiment** = décide où sont les murs, les portes
- 👷 **Architecte réseau** = décide où sont les câbles, qui peut parler à qui

---

## 🎯 Ton rôle : 3 grandes missions

### Mission 1️⃣ : Définir les adresses IP (le "plan d'adressage")

**C'est quoi ?**  
Chaque machine a besoin d'une adresse, comme chaque maison a un numéro de rue.

**Exemple concret** :
- Ta maison : **15 rue Victor Hugo**
- Machine bdd1 : **192.168.63.31**

**Pourquoi c'est important ?**  
Si deux machines ont la même adresse → conflit ! Comme deux maisons avec le même numéro.

**Ce que tu as déjà fait** ✅ :
```ruby
# Dans ton Vagrantfile
bdd1 → 192.168.63.31
bdd2 → 192.168.63.32
app1 → 192.168.63.21
app2 → 192.168.63.22
lb1  → 192.168.63.11
```

C'est ton **plan d'adressage** ! Bien organisé, pas de doublon. ✅

---

### Mission 2️⃣ : Configurer le répartiteur de charge (HAProxy)

#### 🤔 C'est quoi un répartiteur de charge ?

**Analogie : Le standard téléphonique d'une entreprise**

Imagine une banque avec **3 conseillers** (app1, app2, app3) :

**Sans répartiteur** ❌ :
```
Client 1 → appelle conseiller 1 (occupé, ça sonne dans le vide)
Client 2 → appelle conseiller 1 (occupé, ça sonne dans le vide)  
Client 3 → appelle conseiller 1 (occupé, ça sonne dans le vide)
Conseiller 2 et 3 → ne font rien
```

**Avec répartiteur (standardiste)** ✅ :
```
Client 1 → standardiste → redirige vers conseiller 1
Client 2 → standardiste → redirige vers conseiller 2
Client 3 → standardiste → redirige vers conseiller 3
Tout le monde travaille !
```

**Dans ton projet** :
```
Utilisateur tape http://localhost:8080
       ↓
    HAProxy (lb1)
       ↓
  Répartit entre app1, app2, app3, ...
```

#### 🎯 Ton travail : Script `scripts/lb.sh`

Tu dois créer un script qui :
1. **Installe HAProxy** sur la machine lb1
2. **Configure HAProxy** pour connaître tous les serveurs app
3. **Active la sonde de santé** (health check)

**Je t'explique la sonde de santé** 👇

---

### Mission 3️⃣ : Configurer la sonde de santé

#### 🤔 C'est quoi une sonde de santé ?

**Analogie : Le contrôleur de train**

Un train avec 5 wagons. Le contrôleur vérifie régulièrement :
- Wagon 1 : ✅ Tout va bien
- Wagon 2 : ✅ Tout va bien  
- Wagon 3 : ❌ Roue cassée → on déconnecte ce wagon
- Wagon 4 : ✅ Tout va bien
- Wagon 5 : ✅ Tout va bien

Le train continue avec 4 wagons au lieu de 5.

**Dans ton projet** :

HAProxy vérifie **toutes les 2-3 secondes** :
```
app1 → GET /sante → 200 OK ✅ (on envoie du trafic)
app2 → GET /sante → 200 OK ✅ (on envoie du trafic)
app3 → GET /sante → 503 ERROR ❌ (on n'envoie PLUS de trafic)
```

**Exigence R4 du projet** :
> "Le répartiteur écarte un serveur défaillant en moins de 5 secondes"

---

## 📚 Les concepts techniques expliqués

### 🔵 Concept 1 : Réseau privé vs port forwarding

#### Réseau privé (192.168.63.0/24)

**C'est quoi ?**  
Un réseau **invisible depuis l'extérieur**, comme une conversation dans une pièce fermée.

**Dans ton projet** :
```
Machines entre elles :
app1 (192.168.63.21) → bdd1 (192.168.63.31) ✅ Elles se voient
app2 (192.168.63.22) → bdd1 (192.168.63.31) ✅ Elles se voient

Ton PC Windows → app1 (192.168.63.21) ❌ Tu ne peux PAS accéder directement
```

**Pourquoi ?**  
Sécurité ! Les serveurs d'application et la base ne sont pas exposés à l'extérieur.

#### Port forwarding (8080 → 80)

**C'est quoi ?**  
Une "porte" pour accéder de l'extérieur.

**Dans ton Vagrantfile** :
```ruby
m.vm.network "forwarded_port", guest: 80, host: 8080 if n[:role] == "lb"
```

**Traduction** :
- **guest: 80** = Le port 80 **dans** la machine lb1
- **host: 8080** = Le port 8080 sur **ton PC Windows**
- **Effet** : Quand tu tapes `http://localhost:8080` sur ton PC, ça redirige vers lb1:80

**Schéma** :
```
Ton navigateur Windows
http://localhost:8080
       ↓
  Port forwarding
       ↓
lb1 (192.168.63.11:80)
       ↓
app1, app2, app3...
       ↓
bdd1 (192.168.63.31:5432)
```

**Exigence R8** :
> "Seul le répartiteur expose un port vers l'hôte"

C'est pour ça que **seul lb1** a un forwarded_port ! ✅

---

### 🔵 Concept 2 : Source unique de vérité

#### 🤔 Le problème sans source unique

Imagine que tu écris deux fois la même information :

**Fichier 1** : Vagrantfile
```ruby
app1 → 192.168.63.21
app2 → 192.168.63.22
```

**Fichier 2** : Configuration HAProxy
```
backend app_servers
    server app1 192.168.63.21:3000
    server app2 192.168.63.22:3000
```

**Problème** :
- Tu ajoutes app3 dans Vagrantfile
- Tu **oublies** de l'ajouter dans HAProxy
- **Résultat** : app3 démarre mais ne reçoit JAMAIS de trafic ! 😱

#### ✅ Solution : Source unique de vérité

**Une seule source de vérité** = `config/noeuds.yml`

**Comment ça marche ?**

**Étape 1** : Vagrantfile génère `config/noeuds.yml` :
```ruby
# Vagrantfile
NOEUDS = []
NOEUDS << { nom: "app1", ip: "192.168.63.21", role: "app" }
NOEUDS << { nom: "app2", ip: "192.168.63.22", role: "app" }
# Si tu ajoutes app3 ici, il sera automatiquement dans noeuds.yml
File.write("config/noeuds.yml", NOEUDS.to_yaml)
```

**Étape 2** : Le script `scripts/lb.sh` lit ce fichier :
```bash
# scripts/lb.sh
# Lit config/noeuds.yml et génère la config HAProxy
yq '.[] | select(.role == "app")' /vagrant/config/noeuds.yml
```

**Résultat** :
```
Tu changes NB_APP=4
    ↓
Vagrantfile crée 4 machines app
    ↓
config/noeuds.yml contient 4 entrées app
    ↓
scripts/lb.sh lit ce fichier
    ↓
HAProxy est configuré avec 4 backends
    ↓
TOUT EST SYNCHRONISÉ AUTOMATIQUEMENT ! ✅
```

**Exigence R3** :
> "Le nombre de serveurs applicatifs est un paramètre. Passer de 2 à 4 se fait en changeant une seule valeur."

C'est exactement ça ! 🎯

---

### 🔵 Concept 3 : Idempotence

#### 🤔 C'est quoi l'idempotence ?

**Définition simple** :  
Exécuter une commande **1 fois** ou **100 fois** donne le **même résultat**.

**Analogie : L'interrupteur**

**Idempotent** ✅ :
```
Interrupteur lumière :
- J'appuie 1 fois → lumière allumée
- J'appuie encore → lumière allumée (déjà allumée, rien ne change)
- J'appuie encore → lumière allumée (déjà allumée, rien ne change)
Résultat : Toujours "lumière allumée"
```

**Non-idempotent** ❌ :
```
Bouton "ajouter 1 euro au compte" :
- J'appuie 1 fois → +1 euro
- J'appuie encore → +1 euro (maintenant +2 euros)
- J'appuie encore → +1 euro (maintenant +3 euros)
Résultat : Change à chaque fois !
```

#### Dans ton script `scripts/lb.sh`

**Mauvais script (non-idempotent)** ❌ :
```bash
# Mauvais !
echo "server app1 192.168.63.21:3000" >> /etc/haproxy/haproxy.cfg

# Si tu rejoues 3 fois :
# server app1 192.168.63.21:3000
# server app1 192.168.63.21:3000
# server app1 192.168.63.21:3000
# → 3 fois la même ligne ! Bug !
```

**Bon script (idempotent)** ✅ :
```bash
# Bon !
cat > /etc/haproxy/haproxy.cfg << EOF
backend app_servers
    server app1 192.168.63.21:3000
EOF

# Si tu rejoues 3 fois : le fichier est ÉCRASÉ à chaque fois
# Résultat : toujours le même fichier ✅
```

**Exigence R2** :
> "vagrant provision rejoué deux fois de suite ne modifie rien et n'échoue pas"

---

## 📋 Récapitulatif : Ce que tu dois comprendre

| Concept | Analogie | Dans le projet |
|---------|----------|----------------|
| **Plan d'adressage** | Numéros de maison | 192.168.63.21, .22, .31... |
| **Répartiteur de charge** | Standardiste téléphonique | HAProxy répartit entre app1, app2... |
| **Sonde de santé** | Contrôleur de train | HAProxy teste GET /sante toutes les 3s |
| **Réseau privé** | Pièce fermée | Les VMs se parlent entre elles |
| **Port forwarding** | Porte d'entrée | localhost:8080 → lb1:80 |
| **Source unique** | Carnet d'adresses unique | config/noeuds.yml |
| **Idempotence** | Interrupteur | Rejouer le script = même résultat |

---

## 🎯 Tes 3 fichiers à créer (demain)

### Fichier 1 : `scripts/lb.sh` (Script d'installation HAProxy)

**Ce qu'il fait** :
1. Installe HAProxy
2. Lit `config/noeuds.yml`
3. Génère `/etc/haproxy/haproxy.cfg` avec tous les serveurs app
4. Configure la sonde de santé
5. Démarre HAProxy

**Taille** : ~50 lignes

---

### Fichier 2 : `config/haproxy.cfg.template` (Template de configuration)

**Ce qu'il fait** :
- Définit comment HAProxy doit répartir les requêtes
- Configure les health checks

**Taille** : ~30 lignes

---

### Fichier 3 : Test `docs/test-repartition.md` (Documentation des tests)

**Ce qu'il fait** :
- Explique comment tester la répartition (scénario V1)
- Explique comment tester la panne d'un serveur (scénario V2)

**Taille** : ~20 lignes

---

## 💡 Questions pour vérifier ta compréhension

**Question 1** : Pourquoi on utilise un répartiteur de charge ?  
<details>
<summary>Réponse</summary>
Pour distribuer les requêtes entre plusieurs serveurs applicatifs, éviter qu'un seul soit surchargé.
</details>

**Question 2** : C'est quoi une sonde de santé ?  
<details>
<summary>Réponse</summary>
HAProxy teste régulièrement GET /sante sur chaque serveur. Si un serveur répond 503, HAProxy arrête de lui envoyer du trafic.
</details>

**Question 3** : Pourquoi seul lb1 a un forwarded_port ?  
<details>
<summary>Réponse</summary>
Sécurité (exigence R8) : seul le load balancer est exposé à l'extérieur, les serveurs app et la BDD restent cachés.
</details>

**Question 4** : C'est quoi l'idempotence ?  
<details>
<summary>Réponse</summary>
Rejouer le même script plusieurs fois donne toujours le même résultat, sans créer de doublons ou d'erreurs.
</details>

**Question 5** : Pourquoi config/noeuds.yml est important ?  
<details>
<summary>Réponse</summary>
C'est la source unique de vérité : si tu ajoutes app3 dans Vagrantfile, il sera automatiquement ajouté dans la config HAProxy. Pas de désynchronisation !
</details>

---

## 🚀 Prochaine étape (demain)

Maintenant qu'on a bien compris les concepts, on va **créer le script `scripts/lb.sh`** ensemble.

Je te guiderai ligne par ligne ! 😊

---

## ❓ Des questions ?

N'hésite pas à me demander d'expliquer à nouveau un concept que tu n'as pas compris !

Les analogies t'ont aidée ? Veux-tu que j'en rajoute pour d'autres concepts ? 🤔
