![MedusaGIF](https://github.com/user-attachments/assets/45474ab3-599f-4084-897d-1e78d1848bba)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/WhiteMuush/Medusa/actions/workflows/ci.yml/badge.svg)](https://github.com/WhiteMuush/Medusa/actions/workflows/ci.yml)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

Medusa is a bash orchestration toolkit that deploys and manages **35 open-source cybersecurity tools** via an interactive menu or the command line.

---

https://github.com/user-attachments/assets/2e23dc94-f597-4325-a44b-07263c609d04

## Table of contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Modules](#modules)
- [Architecture](#architecture)
- [Environments](#environments)
- [Available tools](#available-tools)
- [Default ports](#default-ports)
- [Security](#security)

---

## Prerequisites

- `docker` : required, container deployment
- `docker compose` or `docker-compose` : required, service orchestration
- `git` : required, cloning official repositories
- `curl` : recommended, downloading installers
- `python3` : recommended, UUID generation
- `pip3` : recommended, installing CLI tools (semgrep, prowler…)
- `openssl` : recommended, password generation

Check prerequisites:

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

No external dependencies beyond the system prerequisites. Everything is contained in a single directory.

---

## Usage

### Interactive menu

```bash
./medusa.sh
```

Keyboard navigation:

- `1–4` : Select a module
- `5` : Status Dashboard
- `6` : Start all deployed tools
- `7` : Stop all tools
- `C` : System configuration
- `Q` : Quit

### Non-interactive CLI

```bash
./medusa.sh deploy <tool>
./medusa.sh start <tool|all>
./medusa.sh stop <tool|all>
./medusa.sh restart <tool>
./medusa.sh status [tool]
./medusa.sh logs <tool> [lines]
./medusa.sh remove <tool>
./medusa.sh list [soc|grc|integration|ot]
./medusa.sh check
./medusa.sh version
```

Examples:

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

14 tools covering a full SOC stack: SIEM, XDR, NDR, CTI, SOAR, endpoint and network forensics.

### 2. GRC / Governance & Compliance

5 tools for risk management, multi-framework compliance (ISO 27001, NIS2, DORA, GDPR), system hardening, and phishing simulation.

### 3. Integration (IAM, Cloud, CI/CD)

11 tools covering identity, secrets, container/IaC/cloud vulnerability scanning, SAST, DAST, and secret detection in repositories.

### 4. OT / Industrial Security

5 tools for passive industrial network monitoring, ICS/SCADA asset mapping, and OT vulnerability scanning.

---

## Architecture

```
medusa/
├── medusa.sh                   # Main entry point
├── lib/
│   ├── core.sh                 # Colors, utilities, Docker helpers, tool registry
│   ├── modules.sh              # Interactive menus, dashboard, session init
│   ├── deploy_soc.sh           # SOC deployment functions
│   ├── deploy_grc.sh           # GRC deployment functions
│   ├── deploy_integration.sh   # Integration deployment functions
│   └── deploy_ot.sh            # OT deployment functions
└── medusa_deployments/
    └── <env_name>/
        └── <tool>/
            ├── docker-compose.yml
            ├── .env
            └── credentials.txt     # chmod 600
```

Each tool is isolated in its own subdirectory. Installation status is determined by the presence of `docker-compose.yml` (Docker tools) or `.installed` (CLI tools).

---

## Environments

Medusa isolates each working context in a named environment. At startup, three options are offered:

- `1` : Create a new environment with a custom name
- `2` : Load an existing environment
- `3` : Auto-generate a name (`env_YYYYMMDD_HHMMSS`)

Deployments are stored under `medusa_deployments/<env_name>/`. This allows maintaining separate contexts: lab, client audit, training, etc.

In CLI mode, set the environment via the `ENV_NAME` variable:

```bash
ENV_NAME=lab_soc ./medusa.sh deploy wazuh
```

---

## Available tools

### SOC / Detection & Response

- [**wazuh**](https://github.com/wazuh/wazuh-docker) `docker` : SIEM/XDR, detection, response, compliance
- [**security-onion**](https://github.com/Security-Onion-Solutions/securityonion) `vm` : NDR, network monitoring (Suricata + Zeek)
- [**suricata**](https://github.com/OISF/suricata) `docker` : High-performance network IDS/IPS
- [**zeek**](https://github.com/zeek/zeek) `docker` : Passive network traffic analysis
- [**opencti**](https://github.com/OpenCTI-Platform/opencti) `docker` : CTI platform, threat intelligence
- [**misp**](https://github.com/MISP/misp-docker) `docker` : Indicators of compromise sharing
- [**dfir-iris**](https://github.com/dfir-iris/iris-web) `docker` : Case management, forensic investigation
- [**cortex**](https://github.com/TheHive-Project/Cortex) `docker` : Observable enrichment and active response
- [**velociraptor**](https://github.com/Velocidex/velociraptor) `docker` : Endpoint forensics and threat hunting
- [**shuffle**](https://github.com/Shuffle/Shuffle) `docker` : SOAR, orchestration and automation
- [**yara**](https://github.com/VirusTotal/yara) `cli` : Malware detection rules
- [**grr**](https://github.com/google/grr) `docker` : Remote incident response (Google)
- [**arkime**](https://github.com/arkime/arkime) `docker` : Network packet capture and indexing
- [**sigma**](https://github.com/SigmaHQ/sigma) `cli` : Generic multi-SIEM detection rules

### GRC / Governance & Compliance

- [**eramba**](https://github.com/eramba/docker) `docker` : GRC, policies, risks, compliance
- [**ciso-assistant**](https://github.com/intuitem/ciso-assistant-community) `docker` : Lightweight GRC, multi-framework (NIS2, DORA, ISO 27001)
- [**simplerisk**](https://github.com/simplerisk/simplerisk) `docker` : Risk management, registers and scoring
- [**openscap**](https://github.com/OpenSCAP/openscap) `cli` : Compliance evaluation and system hardening
- [**gophish**](https://github.com/gophish/gophish) `docker` : Phishing simulation and awareness

### Integration (IAM, Cloud, CI/CD)

- [**keycloak**](https://github.com/keycloak/keycloak) `docker` : IAM, SSO, MFA, identity federation
- [**teleport**](https://github.com/gravitational/teleport) `cli` : PAM, privileged access SSH/Kubernetes/DB
- [**vault**](https://github.com/hashicorp/vault) `docker` : Secrets manager (dev mode)
- [**trivy**](https://github.com/aquasecurity/trivy) `cli` : Container and IaC vulnerability scanner
- [**semgrep**](https://github.com/semgrep/semgrep) `cli` : SAST, static code analysis
- [**owasp-zap**](https://github.com/zaproxy/zaproxy) `docker` : DAST, web security scanner
- [**gitleaks**](https://github.com/gitleaks/gitleaks) `cli` : Secret detection in Git repositories
- [**checkov**](https://github.com/bridgecrewio/checkov) `cli` : Static IaC analysis (Terraform, Kubernetes)
- [**prowler**](https://github.com/prowler-cloud/prowler) `cli` : Cloud security audit AWS/Azure/GCP
- [**scoutsuite**](https://github.com/nccgroup/ScoutSuite) `cli` : Multi-cloud audit with HTML report
- [**falco**](https://github.com/falcosecurity/falco) `docker` : Cloud-native runtime threat detection

### OT / Industrial Security

- [**malcolm**](https://github.com/cisagov/Malcolm) `docker` : OT network traffic analysis, industrial protocols (CISA)
- [**grfics**](https://github.com/Fortiphyd/GRFICSv2) `vm` : SCADA/ICS simulation for training labs
- [**nmap**](https://github.com/nmap/nmap) `cli` : Network mapping and industrial NSE scripts
- [**openvas**](https://github.com/greenbone/openvas-scanner) `docker` : Network vulnerability scanner
- [**grassmarlin**](https://github.com/nsacyber/GRASSMARLIN) `vm` : Passive ICS/SCADA network mapping (NSA)

> `vm` tools display manual deployment instructions (ISO, VirtualBox/VMware).

---

## Default ports

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
- Falco : daemon (no web interface)

---

## Security

- Passwords are randomly generated (24 alphanumeric characters via `openssl`)
- Each `credentials.txt` file is created with `chmod 600`
- The `medusa_deployments/` directory must never be committed (see `.gitignore`)
- Vault is deployed in **dev** mode by default: in-memory data only, do not use in production
- The script warns when run as `root` but does not block execution

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md)
for local setup, code conventions, and the PR checklist. The
recipe for **adding a new tool** is in
[docs/ADDING_A_TOOL.md](docs/ADDING_A_TOOL.md), and the internal
architecture is documented in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

To report a vulnerability, see [SECURITY.md](SECURITY.md) —
**do not open a public issue**.

## License

[**MIT**](LICENSE)
