![MedusaGIF](https://github.com/user-attachments/assets/45474ab3-599f-4084-897d-1e78d1848bba)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/WhiteMuush/Medusa/actions/workflows/ci.yml/badge.svg)](https://github.com/WhiteMuush/Medusa/actions/workflows/ci.yml)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

Medusa est un toolkit bash d'orchestration qui déploie et gère **35 outils open source de cybersécurité** via un menu interactif ou en ligne de commande.

---

https://github.com/user-attachments/assets/2e23dc94-f597-4325-a44b-07263c609d04

## Sommaire

- [Prérequis](#prérequis)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Modules](#modules)
- [Architecture](#architecture)
- [Environnements](#environnements)
- [Outils disponibles](#outils-disponibles)
- [Ports par défaut](#ports-par-défaut)
- [Sécurité](#sécurité)

---

## Prérequis

- `docker` : obligatoire, déploiement des conteneurs
- `docker compose` ou `docker-compose` : obligatoire, orchestration des services
- `git` : obligatoire, clonage des dépôts officiels
- `curl` : recommandé, téléchargement d'installeurs
- `python3` : recommandé, génération d'UUIDs
- `pip3` : recommandé, installation d'outils CLI (semgrep, prowler…)
- `openssl` : recommandé, génération de mots de passe

Vérifier les prérequis :

```bash
./medusa.sh check
```

---

## Installation

```bash
git clone https://github.com/WhiteMuush/medusa.git
cd medusa
chmod +x medusa.sh
./medusa.sh
```

Aucune dépendance externe au-delà des prérequis système. Tout est contenu dans un répertoire unique.

---

## Utilisation

### Menu interactif

```bash
./medusa.sh
```

Navigation au clavier :

- `1–4` : Sélectionner un module
- `5` : Status Dashboard
- `6` : Démarrer tous les outils déployés
- `7` : Arrêter tous les outils
- `C` : Configuration système
- `Q` : Quitter

### CLI non-interactif

```bash
./medusa.sh deploy <outil>
./medusa.sh start <outil|all>
./medusa.sh stop <outil|all>
./medusa.sh restart <outil>
./medusa.sh status [outil]
./medusa.sh logs <outil> [lignes]
./medusa.sh remove <outil>
./medusa.sh list [soc|grc|integration|ot]
./medusa.sh check
./medusa.sh version
```

Exemples :

```bash
./medusa.sh deploy wazuh
./medusa.sh start opencti
./medusa.sh logs misp 200
./medusa.sh list soc
ENV_NAME=audit_client ./medusa.sh deploy keycloak
```

---

## Modules

### 1. SOC / Detection & Response

14 outils couvrant l'ensemble d'un SOC : SIEM, XDR, NDR, CTI, SOAR, forensique endpoint et réseau.

### 2. GRC / Governance & Compliance

5 outils pour la gestion des risques, la conformité multi-frameworks (ISO 27001, NIS2, DORA, RGPD), le durcissement système et la simulation de phishing.

### 3. Integration (IAM, Cloud, CI/CD)

11 outils couvrant l'identité, les secrets, le scan de vulnérabilités conteneurs/IaC/cloud, SAST, DAST et la détection de secrets dans les dépôts.

### 4. OT / Industrial Security

5 outils pour la surveillance passive de réseaux industriels, la cartographie d'actifs ICS/SCADA et le scan de vulnérabilités OT.

---

## Architecture

```
medusa/
├── medusa.sh                   # Point d'entrée principal
├── lib/
│   ├── core.sh                 # Couleurs, utilitaires, Docker, registre des outils
│   ├── modules.sh              # Menus interactifs, dashboard, initialisation session
│   ├── deploy_soc.sh           # Fonctions de déploiement SOC
│   ├── deploy_grc.sh           # Fonctions de déploiement GRC
│   ├── deploy_integration.sh   # Fonctions de déploiement Integration
│   └── deploy_ot.sh            # Fonctions de déploiement OT
└── medusa_deployments/
    └── <env_name>/
        └── <tool>/
            ├── docker-compose.yml
            ├── .env
            └── credentials.txt     # chmod 600
```

Chaque outil est isolé dans son propre sous-répertoire. Le statut d'installation est déterminé par la présence de `docker-compose.yml` (outils Docker) ou `.installed` (outils CLI).

---

## Environnements

Medusa isole chaque contexte de travail dans un environnement nommé. Au démarrage, trois options sont proposées :

- `1` : Créer un nouvel environnement avec un nom personnalisé
- `2` : Charger un environnement existant
- `3` : Auto-générer un nom (`env_YYYYMMDD_HHMMSS`)

Les déploiements sont stockés sous `medusa_deployments/<env_name>/`. Cela permet de maintenir des contextes séparés : lab, audit client, formation, etc.

En mode CLI, définir l'environnement via la variable `ENV_NAME` :

```bash
ENV_NAME=lab_soc ./medusa.sh deploy wazuh
```

---

## Outils disponibles

### SOC / Detection & Response

- [**wazuh**](https://github.com/wazuh/wazuh-docker) `docker` : SIEM/XDR, détection, réponse, conformité
- [**security-onion**](https://github.com/Security-Onion-Solutions/securityonion) `vm` : NDR, surveillance réseau (Suricata + Zeek)
- [**suricata**](https://github.com/OISF/suricata) `docker` : IDS/IPS réseau hautes performances
- [**zeek**](https://github.com/zeek/zeek) `docker` : Analyse de trafic réseau passive
- [**opencti**](https://github.com/OpenCTI-Platform/opencti) `docker` : Plateforme CTI, renseignement sur les menaces
- [**misp**](https://github.com/MISP/misp-docker) `docker` : Partage d'indicateurs de compromission
- [**dfir-iris**](https://github.com/dfir-iris/iris-web) `docker` : Gestion de cas, investigation forensique
- [**cortex**](https://github.com/TheHive-Project/Cortex) `docker` : Enrichissement d'observables et réponse active
- [**velociraptor**](https://github.com/Velocidex/velociraptor) `docker` : Forensique endpoint et threat hunting
- [**shuffle**](https://github.com/Shuffle/Shuffle) `docker` : SOAR, orchestration et automatisation
- [**yara**](https://github.com/VirusTotal/yara) `cli` : Règles de détection de malwares
- [**grr**](https://github.com/google/grr) `docker` : Réponse à incident à distance (Google)
- [**arkime**](https://github.com/arkime/arkime) `docker` : Capture et indexation de paquets réseau
- [**sigma**](https://github.com/SigmaHQ/sigma) `cli` : Règles de détection génériques multi-SIEM

### GRC / Governance & Compliance

- [**eramba**](https://github.com/eramba/docker) `docker` : GRC, politiques, risques, conformité
- [**ciso-assistant**](https://github.com/intuitem/ciso-assistant-community) `docker` : GRC léger, multi-frameworks (NIS2, DORA, ISO 27001)
- [**simplerisk**](https://github.com/simplerisk/simplerisk) `docker` : Gestion des risques, registres et scoring
- [**openscap**](https://github.com/OpenSCAP/openscap) `cli` : Évaluation conformité et durcissement système
- [**gophish**](https://github.com/gophish/gophish) `docker` : Simulation de phishing et sensibilisation

### Integration (IAM, Cloud, CI/CD)

- [**keycloak**](https://github.com/keycloak/keycloak) `docker` : IAM, SSO, MFA, fédération d'identités
- [**teleport**](https://github.com/gravitational/teleport) `cli` : PAM, accès privilégiés SSH/Kubernetes/DB
- [**vault**](https://github.com/hashicorp/vault) `docker` : Gestionnaire de secrets (mode dev)
- [**trivy**](https://github.com/aquasecurity/trivy) `cli` : Scanner de vulnérabilités conteneurs et IaC
- [**semgrep**](https://github.com/semgrep/semgrep) `cli` : SAST, analyse statique de code
- [**owasp-zap**](https://github.com/zaproxy/zaproxy) `docker` : DAST, scanner de sécurité web
- [**gitleaks**](https://github.com/gitleaks/gitleaks) `cli` : Détection de secrets dans les dépôts Git
- [**checkov**](https://github.com/bridgecrewio/checkov) `cli` : Analyse statique IaC (Terraform, Kubernetes)
- [**prowler**](https://github.com/prowler-cloud/prowler) `cli` : Audit sécurité cloud AWS/Azure/GCP
- [**scoutsuite**](https://github.com/nccgroup/ScoutSuite) `cli` : Audit multi-cloud avec rapport HTML
- [**falco**](https://github.com/falcosecurity/falco) `docker` : Détection de menaces runtime cloud-native

### OT / Industrial Security

- [**malcolm**](https://github.com/cisagov/Malcolm) `docker` : Analyse trafic réseau OT, protocoles industriels (CISA)
- [**grfics**](https://github.com/Fortiphyd/GRFICSv2) `vm` : Simulation SCADA/ICS pour lab d'entraînement
- [**nmap**](https://github.com/nmap/nmap) `cli` : Cartographie réseau et scripts NSE industriels
- [**openvas**](https://github.com/greenbone/openvas-scanner) `docker` : Scanner de vulnérabilités réseau
- [**grassmarlin**](https://github.com/nsacyber/GRASSMARLIN) `vm` : Cartographie passive réseaux ICS/SCADA (NSA)

> Les outils `vm` affichent les instructions de déploiement manuel (ISO, VirtualBox/VMware).

---

## Ports par défaut

- Wazuh Dashboard : `443`
- OpenCTI : `8080`
- MISP : `443`
- DFIR-IRIS : `4433`
- Cortex : `9001`
- Velociraptor GUI : `8889`
- Shuffle : `3443`
- GRR : `8001`
- Eramba : `8443`
- CISO Assistant : `8443`
- SimpleRisk : `8445`
- GoPhish Admin : `3333`
- Keycloak : `8180`
- Vault : `8200`
- OWASP ZAP : `8090`
- Greenbone/OpenVAS : `9392`
- Arkime : `8005`
- Falco : daemon (pas d'interface web)

---

## Sécurité

- Les mots de passe sont générés aléatoirement (24 caractères alphanumériques via `openssl`)
- Chaque fichier `credentials.txt` est créé avec `chmod 600`
- Le répertoire `medusa_deployments/` ne doit jamais être commité (voir `.gitignore`)
- Vault est déployé en mode **dev** par défaut : données en mémoire uniquement, ne pas utiliser en production
- Le script avertit en cas d'exécution en `root` mais ne bloque pas l'exécution

---

## Contribuer

Les contributions sont bienvenues. Voir [CONTRIBUTING.md](CONTRIBUTING.md)
pour le setup local, les conventions de code et la checklist PR. Le
recipe pour **ajouter un nouvel outil** est dans
[docs/ADDING_A_TOOL.md](docs/ADDING_A_TOOL.md), et l'architecture interne
est documentée dans [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Pour signaler une vulnérabilité, voir [SECURITY.md](SECURITY.md) —
**ne pas ouvrir d'issue publique**.

## Licence

[**MIT**](LICENSE)

