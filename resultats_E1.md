# Extension E1 — Load Balancer redondant (Keepalived / VRRP)

## 1. Objectif

Supprimer le point de défaillance unique que constitue le load balancer `lb1`.
Si `lb1` tombe, le service doit rester joignable à la même adresse IP, sans
aucune intervention manuelle, en moins de 5 secondes.

## 2. Architecture mise en place

| Composant | Adresse IP | Rôle VRRP | Priorité |
|-----------|-----------|-----------|----------|
| `lb1` | 192.168.63.11 | **MASTER** | 100 |
| `lb2` | 192.168.63.12 | **BACKUP** | 90 |
| **VIP partagée** | **192.168.63.10/24** | — | — |

- Protocole : VRRP via Keepalived
- `virtual_router_id` : 51
- `advert_int` : 1 seconde
- Interface réseau : `eth1` (détectée automatiquement via `ip -o -4 addr show | grep 192.168.63`)
- HAProxy identique sur les deux nœuds (mêmes backends `app1` / `app2`)

## 3. Configuration Keepalived

Fichier `/etc/keepalived/keepalived.conf` sur **lb1** (MASTER) :

```
vrrp_instance VI_1 {
    state MASTER
    interface eth1
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass ResultatsBF2026
    }
    virtual_ipaddress {
        192.168.63.10/24
    }
}
```

Sur **lb2** (BACKUP) : identique sauf `state BACKUP` et `priority 90`.

## 4. Vérifications initiales

### 4.1 Qui porte la VIP au repos ?

```
$ vagrant ssh lb1 -c "ip -4 addr show | grep 192.168.63.10"
    inet 192.168.63.10/24 scope global secondary eth1

$ vagrant ssh lb2 -c "ip -4 addr show | grep 192.168.63.10"
    (aucune sortie)
```

→ ✅ `lb1` porte la VIP, `lb2` est en attente.

### 4.2 Service joignable via la VIP

```
$ curl http://192.168.63.10/info
{"hostname":"app1","database":"192.168.63.31:5432/resultats_bf"}
```

→ ✅ La VIP route correctement vers les backends HAProxy.

### 4.3 Statut des services Keepalived

```
$ vagrant ssh lb1 -c "sudo systemctl is-active keepalived"
active

$ vagrant ssh lb2 -c "sudo systemctl is-active keepalived"
active
```

→ ✅ Les deux démons Keepalived sont opérationnels.

## 5. Scénario V6 — Panne du load balancer MASTER

### 5.1 Protocole de test

**Terminal 1** — monitoring continu de la VIP (une requête toutes les 500 ms) :

```bash
while true; do
  t=$(date +%H:%M:%S)
  code=$(curl -s -o /dev/null -w "%{http_code}" -m 1 http://192.168.63.10/info)
  echo "$t → HTTP $code"
  sleep 0.5
done
```

**Terminal 2** — on provoque la panne du MASTER :

```bash
vagrant halt lb1
```

### 5.2 Résultat brut observé

```
22:50:13 → HTTP 200
22:50:13 → HTTP 200
22:50:14 → HTTP 200
22:50:15 → HTTP 200
22:50:16 → HTTP 000        ← panne de lb1 détectée
22:50:18 → HTTP 200        ← lb2 a pris le relais (VIP migrée)
22:50:19 → HTTP 200
22:50:20 → HTTP 200
...                        ← aucune autre erreur sur les 30 secondes suivantes
22:50:51 → HTTP 200
```

### 5.3 Mesures

| Indicateur | Valeur mesurée |
|-----------|----------------|
| Nombre de requêtes perdues (`HTTP 000`) | **1** |
| Durée d'indisponibilité | **2 secondes** |
| Adresse du service pendant la bascule | **192.168.63.10 (inchangée)** |
| Intervention manuelle nécessaire | **Aucune** |
| Exigence < 5 s respectée | ✅ Oui |

### 5.4 Vérification après bascule

```
$ vagrant ssh lb1 -c "ip -4 addr show | grep 192.168.63.10"
    (lb1 est éteint, aucune sortie)

$ vagrant ssh lb2 -c "ip -4 addr show | grep 192.168.63.10"
    inet 192.168.63.10/24 scope global secondary eth1
```

→ ✅ `lb2` est devenu MASTER et porte la VIP.

## 6. Scénario complémentaire — Retour du MASTER initial (préemption)

### 6.1 Protocole

```bash
vagrant up lb1
```

### 6.2 Résultat brut observé

```
23:00:21 → HTTP 200
23:00:22 → HTTP 200
23:00:23 → HTTP 200
23:00:24 → HTTP 000        ← transition lb2 → lb1 (préemption)
23:00:26 → HTTP 200        ← lb1 a repris la VIP
23:00:27 → HTTP 200
```

### 6.3 Mesures

| Indicateur | Valeur mesurée |
|-----------|----------------|
| Nombre de requêtes perdues | **1** |
| Durée d'indisponibilité | **2 secondes** |
| Reprise automatique du rôle MASTER | ✅ Oui (priorité 100 > 90) |

### 6.4 Vérification post-préemption

```
$ vagrant ssh lb1 -c "ip -4 addr show | grep 192.168.63.10"
    inet 192.168.63.10/24 scope global secondary eth1

$ vagrant ssh lb2 -c "ip -4 addr show | grep 192.168.63.10"
    (aucune sortie)
```

→ ✅ `lb1` a repris la VIP, `lb2` est redevenu BACKUP.

## 7. Synthèse

| Critère | Résultat |
|---------|----------|
| Bascule MASTER → BACKUP (panne lb1) | ✅ 2 secondes, 1 requête perdue |
| Bascule BACKUP → MASTER (retour lb1) | ✅ 2 secondes, 1 requête perdue |
| Adresse inchangée pendant les bascules | ✅ 192.168.63.10 |
| Intervention manuelle | ✅ Aucune |
| Respect de l'exigence < 5 s | ✅ Oui |

## 8. Limites connues

- **Split-brain possible** : si le lien réseau entre lb1 et lb2 est rompu (mais
  que les deux restent allumés), chacun peut se proclamer MASTER. Dans ce projet,
  les deux LB sont sur le même segment host-only Vagrant, donc ce cas ne se
  produit pas en pratique. Une production réelle ajouterait un `unicast_peer`
  et/ou un fencing.
- **VRRP multicast** : Keepalived utilise du multicast VRRP (224.0.0.18). Cela
  fonctionne sur le réseau host-only Vagrant, mais dans un environnement cloud
  il faudrait passer en mode unicast.
- **Consommation mémoire** : l'ajout de `lb2` (512 Mo) porte le socle + extension
  à environ 3,5 Go, ce qui reste compatible avec un poste 8 Go si l'extension E2
  (`obs`, 768 Mo) n'est pas allumée en même temps.

## 9. Fichiers modifiés pour E1

- `Vagrantfile` : ajout du nœud `lb2`, correction du port forwarding (uniquement
  `lb1` expose le port 80 vers l'hôte, pour éviter un conflit 8080)
- `scripts/lb.sh` : ajout du bloc Keepalived en fin de script, avec détection
  automatique de l'interface réseau et attribution dynamique du rôle
  MASTER/BACKUP selon le hostname