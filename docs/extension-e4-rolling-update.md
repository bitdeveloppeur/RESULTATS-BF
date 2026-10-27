# Guide de Test - Extension E4 : Déploiement sans coupure (Rolling Update)

> **Projet :** RÉSULTATS-BF  
> **Module :** DevOps et infrastructures reproductibles (Master 1 Informatique - IBAM)  
> **Rôle :** Ingénieur applicatif  
> **Livrables associés :** Dossier d'architecture (L2) & Démonstration (L4)

---

## 1. Objectif de l'Extension E4

Prouver que l'on peut déployer une nouvelle version de l'application (passer de la version `1.0.0` à la version `2.0.0`) **pendant que des candidats consultent le site à pleine charge**, avec :
- **0 seconde d'interruption de service** (*Zero Downtime*).
- **0 requête perdue ou en erreur** (`Failed requests: 0`).

---

## 2. Prérequis

1. L'infrastructure Vagrant doit être active :
   ```powershell
   vagrant status
   ```
   *(Toutes les machines `bdd1`, `bdd2`, `app1`, `app2` et `lb1` doivent être en statut `running`).*

2. L'accès au site fonctionne sur votre machine hôte :  
   👉 **http://localhost:8088/**

---

## 3. Protocole de Test Pas-à-Pas (Démonstration & Captures d'écran)

Pour réaliser la démonstration exigée par le professeur (ou prendre les captures d'écran pour le rapport) :

### Étape 1 : Vérifier la version actuelle en ligne
Ouvrez votre navigateur ou tapez dans PowerShell :
```powershell
curl.exe -s http://localhost:8088/
```
**Résultat attendu :**
```json
{"service":"RESULTATS-BF","version":"1.0.0","hostname":"app1","docs":"/docs"}
```

---

### Étape 2 : Préparer la nouvelle version (v2.0.0) dans le code
Ouvrez le fichier `app/server.py` et modifiez le numéro de version de `1.0.0` vers `2.0.0` :

```python
# Dans app/server.py :
app = FastAPI(
    title="RÉSULTATS-BF",
    description="API de consultation des résultats d'examens",
    version="2.0.0",   # <--- Modifier ici
    lifespan=lifespan
)

@app.get("/")
async def root():
    return {
        "service": "RESULTATS-BF",
        "version": "2.0.0",   # <--- Modifier ici
        "message": "Bienvenue sur la version 2.0 (Deploiement Rolling Update reussi)",
        "hostname": socket.gethostname(),
        "docs": "/docs"
    }
```
*Enregistrez le fichier.*

---

### Étape 3 : Ouvrir DEUX terminaux PowerShell côte à côte

####  Terminal 1 (À gauche) : Simuler le trafic des utilisateurs en continu
Lancez un flux continu de requêtes pour simuler des candidats qui chargent le site sans arrêt :

* **Option A (Avec Apache Bench - Recommandé par le sujet) :**
  ```powershell
  ab -n 3000 -c 10 http://localhost:8088/
  ```

* **Option B (En boucle PowerShell native si Apache Bench n'est pas installé) :**
  ```powershell
  while ($true) { curl.exe -s http://localhost:8088/ ; Start-Sleep -Milliseconds 150 }
  ```

#### 🚀 Terminal 2 (À droite) : Lancer le Rolling Update
Pendant que le Terminal 1 est en train d'envoyer des requêtes, lancez immédiatement dans le Terminal 2 :

```powershell
.\scripts\rolling-update.ps1
```

---

### Étape 4 : Ce qui se passe sous vos yeux

1. Le script détecte dynamiquement `app1` et `app2`.
2. Il isole `app1` dans HAProxy (`state maint`), draine les connexions en cours (pause de 2s), met à jour le code vers `2.0.0`, teste la sonde `/sante` (`200 OK`), puis réactive `app1` (`state ready`).
3. Il passe ensuite à `app2` et répète la même procédure.
4. Pendant tout ce temps, dans le **Terminal 1**, **aucune requête ne plante**. Vous voyez même la version basculer en direct de `1.0.0` à `2.0.0` !

---

## 4. Les 3 Captures d'écran à inclure dans votre Dossier écrit

1. **Capture 1 (Le script de déploiement) :**  
   Capture du terminal montrant la fin de l'exécution de `.\scripts\rolling-update.ps1` avec tous les indicateurs `[OK]` et le bandeau vert `[SUCCES]`.

2. **Capture 2 (La preuve du test de charge) :**  
   Capture du rapport Apache Bench (`ab`) montrant :
   ```text
   Complete requests:      3000
   Failed requests:        0        <--- C'est cette ligne qui donne les points !
   ```

3. **Capture 3 (Le navigateur web) :**  
   Capture de la page **http://localhost:8088/** montrant le JSON retourné avec `"version": "2.0.0"`.

---

## 5. Questions pièges possibles du professeur en soutenance

**Q1 : Pourquoi ne pas simplement faire un `vagrant reload` ou relancer le service sur tous les serveurs en même temps ?**  
> *Réponse :* Cela couperait le service pendant plusieurs secondes pour tous les utilisateurs (erreur 502 Bad Gateway). Le Rolling Update traite les serveurs un par un afin de maintenir une disponibilité de 100 %.

**Q2 : Comment HAProxy sait-il qu'il ne doit plus envoyer de trafic à `app1` pendant la mise à jour ?**  
> *Réponse :* Grâce au socket d'administration en mémoire vive (`/run/haproxy/admin.sock`). Le script envoie la commande `set server app_servers/app1 state maint` via l'outil `socat`. HAProxy bascule instantanément tout le trafic restant sur les autres serveurs actifs.

**Q3 : Pourquoi le script fait-il une pause de 2 secondes après avoir mis le serveur en maintenance ?**  
> *Réponse :* C'est le temps de **drainage**. Cela permet aux requêtes qui étaient déjà arrivées sur le serveur quelques millisecondes plus tôt de se terminer proprement avant de couper le service Python.

**Q4 : Que se passe-t-il si la nouvelle version comporte un bug fatal et refuse de démarrer ?**  
> *Réponse :* La sonde de santé `/sante` échouera (ne renverra pas 200). Le script de déploiement s'interrompt immédiatement en alerte et ne touche jamais aux autres serveurs. La production reste donc en ligne sur les serveurs sains restants.
