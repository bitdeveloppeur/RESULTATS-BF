# Architecture RÉSULTATS-BF

##  Schéma d'architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                 RÉSEAU PRIVÉ DU GROUPE - 192.168.63.0/24                │
│                                                                           │
│  ┌──────────────┐                                                        │
│  │ Poste hôte   │  Port 8080                                             │
│  │   (Windows)  │◄──────────┐                                            │
│  └──────────────┘            │                                            │
│                              │                                            │
│                         ┌────▼─────────────────────────────────┐         │
│                         │        lb1 (actif)                   │         │
│                         │  HAProxy + keepalived                │         │
│                         │  192.168.63.11                       │         │
│                         │  RAM: 512 Mo                         │         │
│                         └────┬───────────┬────────────┬────────┘         │
│                              │           │            │                   │
│                    ┌─────────┴───┐   ┌──┴──────┐  ┌─┴──────────┐        │
│                    │             │   │         │  │            │        │
│    N serveurs  ┌───▼──────┐  ┌──▼───────┐  ┌──▼──────┐     ┌──▼──────┐ │
│    applicatifs │   app1   │  │   app2   │  │  app3   │ ... │  appN   │ │
│    (N ≥ 2)     │ Python/  │  │ Python/  │  │ Python/ │     │ Python/ │ │
│                │   Node   │  │   Node   │  │  Node   │     │  Node   │ │
│    Stateless   │ .63.21   │  │  .63.22  │  │ .63.23  │     │ .63.2N  │ │
│    (aucun      │ 512 Mo   │  │  512 Mo  │  │ 512 Mo  │     │ 512 Mo  │ │
│     état)      └───┬──────┘  └──┬───────┘  └──┬──────┘     └──┬──────┘ │
│                    │            │             │               │        │
│                    └────────────┴─────────────┴───────────────┘        │
│                                  │                                      │
│                            HTTP  │  SQL 5432                            │
│                                  │                                      │
│                    ┌─────────────▼─────────────┐                        │
│                    │        bdd1 (primaire)    │                        │
│                    │     PostgreSQL 14         │                        │
│                    │     192.168.63.31         │                        │
│                    │     RAM: 768 Mo           │                        │
│                    │  lecture + écriture       │                        │
│                    └─────────────┬─────────────┘                        │
│                                  │                                      │
│                            Réplication                                  │
│                            en flux (streaming)                          │
│                            SQL 5432                                     │
│                                  │                                      │
│                    ┌─────────────▼─────────────┐                        │
│                    │       bdd2 (réplique)     │                        │
│                    │     PostgreSQL 14         │                        │
│                    │     192.168.63.32         │                        │
│                    │     RAM: 768 Mo           │                        │
│                    │  lecture seule (promo-    │                        │
│                    │  uvable en primaire)      │                        │
│                    └───────────────────────────┘                        │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘

                    IP virtuelle .5 (Extension E1 - lb2)
                    Supervision .41 (Extension E2 - obs)
                    Cache Redis (Extension E3)
```

---

##  Justification des choix d'architecture

### 1. Résilience

#### 1.1 Au niveau applicatif
- **N serveurs sans état** : Aucune session en mémoire, tout l'état vit dans la base
- **Sonde de santé active** : HAProxy interroge `/sante` toutes les 2-3 secondes
- **Retrait automatique** : Un serveur défaillant est écarté en < 5 secondes

**Impact** : La panne d'un serveur applicatif n'interrompt jamais le service

#### 1.2 Au niveau base de données
- **Réplication en flux** : bdd2 réplique bdd1 en continu
- **Procédure de bascule** : bdd2 peut être promue en primaire
- **Détection de panne** : Le endpoint `/sante` retourne 503 si la base est inaccessible

**Impact** : Les données sont dupliquées ; la panne de bdd1 peut être compensée

#### 1.3 Au niveau réseau (Extension E1)
- **lb2 en standby** : Deuxième load balancer avec keepalived
- **IP virtuelle VRRP** : Bascule automatique entre lb1 et lb2
- **Heartbeat** : Détection de panne en < 5 secondes

**Impact** : Aucun point de défaillance unique (SPOF)

---

### 2. Scalabilité

#### 2.1 Scalabilité horizontale
- **Variable NB_APP** : Passer de 2 à 4 serveurs = changer une seule valeur
- **Configuration auto-générée** : HAProxy lit `config/noeuds.yml`
- **Aucune adresse en dur** : La liste des backends est engendrée dynamiquement

**Impact** : Ajouter de la capacité = ajouter des machines, pas réécrire du code

#### 2.2 Source unique de vérité (R3)
```ruby
# Vagrantfile génère config/noeuds.yml
(1..NB_APP).each do |i|
  NOEUDS << { nom: "app#{i}", ip: "#{RESEAU}.#{20 + i}", ... }
end
```

Les scripts de provisionnement lisent ce fichier pour configurer HAProxy :
```bash
# scripts/lb.sh génère /etc/haproxy/haproxy.cfg
yq '.[] | select(.role == "app")' /vagrant/config/noeuds.yml
```

**Impact** : Une seule source de vérité → pas de désynchronisation

---

### 3. Reproductibilité (R1, R2)

#### 3.1 Infrastructure as Code
- **Vagrantfile** : Décrit toutes les machines
- **Scripts shell** : Provisionnent chaque rôle
- **Idempotence** : Exécutables plusieurs fois sans effet de bord

#### 3.2 Gestion des secrets (R7)
- `.env.exemple` versionné avec des placeholders
- `.env` local non versionné (dans `.gitignore`)
- Variables injectées lors du provisionnement

#### 3.3 Portabilité Windows/Linux
- `.gitattributes` : Force LF pour les scripts shell
- Évite les erreurs `/bin/bash^M: bad interpreter`

---

##  Tableau récapitulatif

| Exigence | Composant | Mécanisme | Vérification |
|----------|-----------|-----------|--------------|
| **Résilience app** | HAProxy + sonde | Health check GET /sante | Scénario V2 |
| **Résilience data** | PostgreSQL | Streaming replication | Scénario V4 |
| **Scalabilité** | Vagrantfile | Variable NB_APP | Scénario V3 |
| **Reproductibilité** | Scripts | Idempotence | Scénario V5 |
| **Sécurité** | .env | Variables d'environnement | Git history |
| **Isolation** | Réseau privé | 192.168.63.0/24 | Vagrantfile |

---


##  Évolutions possibles

1. **Automatiser la bascule de base** : Patroni ou repmgr
2. **Chiffrement TLS** : Certificats Let's Encrypt
3. **WAF** : ModSecurity devant HAProxy
4. **Backup automatisé** : pgBackRest
5. **Multi-datacenter** : Réplication asynchrone vers un site distant

---

## Dimensionnement

### Capacité estimée (avec 2 serveurs applicatifs)
- **Débit** : ~200-500 req/s (selon complexité requête SQL)
- **Latence** : < 100 ms (P95)
- **Connexions simultanées** : ~1000

### Montée en charge (NB_APP=4)
- **Débit** : ~350-800 req/s
- **Gain** : +75-60% (non linéaire, dû aux contraintes VirtualBox)

### Limites connues
- **CPU** : Les VMs se partagent les cœurs de l'hôte
- **I/O disque** : Un seul disque physique pour toutes les VMs
- **Réseau** : Réseau virtuel (pas de limitation physique)

---

##  Références

- HAProxy best practices : http://www.haproxy.org/
- PostgreSQL replication : https://www.postgresql.org/docs/current/warm-standby.html
- Vagrant multi-machine : https://developer.hashicorp.com/vagrant/docs/multi-machine
