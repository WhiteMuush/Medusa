![MedusaGIF](https://github.com/user-attachments/assets/45474ab3-599f-4084-897d-1e78d1848bba)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/WhiteMuush/Medusa/actions/workflows/ci.yml/badge.svg)](https://github.com/WhiteMuush/Medusa/actions/workflows/ci.yml)
[![Wiki](https://img.shields.io/badge/docs-wiki-blue.svg)](https://github.com/WhiteMuush/Medusa/wiki)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](.github/CONTRIBUTING.md)

Medusa is a Bash orchestration toolkit that deploys and manages **35 open-source cybersecurity tools** through an interactive menu or the command line. Each tool runs isolated in its own directory, grouped into named environments, deployed via Docker Compose or installed as a CLI binary.

---

https://github.com/user-attachments/assets/2e23dc94-f597-4325-a44b-07263c609d04

## Highlights

- **Single entry point**, pure Bash, no runtime dependency beyond the system prerequisites.
- **35 tools** across 4 modules: SOC, GRC, Integration, OT.
- **Two interfaces**, an interactive TUI and a scriptable CLI.
- **Environment isolation**, separate deployment trees for lab, audit, training.
- **No database, no daemon**, the filesystem under `medusa_deployments/` is the single source of truth.

## Quick start

```bash
git clone https://github.com/WhiteMuush/Medusa.git
cd Medusa
chmod +x medusa.sh
./medusa.sh check      # verify prerequisites
./medusa.sh            # launch interactive menu
```

Non-interactive usage:

```bash
./medusa.sh deploy wazuh
./medusa.sh start opencti
./medusa.sh logs misp 200
./medusa.sh list soc
ENV_NAME=audit_client ./medusa.sh deploy keycloak
```

**Prerequisites**: `docker`, `docker compose` (or `docker-compose`), `git` required; `curl`, `python3`, `pip3`, `openssl` recommended. Run `./medusa.sh check` to verify.

## Documentation

Full documentation lives in the **[Wiki](https://github.com/WhiteMuush/Medusa/wiki)**.

| Topic | Page |
|---|---|
| Prerequisites, install, uninstall | [Installation](https://github.com/WhiteMuush/Medusa/wiki/Installation) |
| Every command and the menu | [Usage](https://github.com/WhiteMuush/Medusa/wiki/Usage) |
| Environment variables and the config page | [Configuration](https://github.com/WhiteMuush/Medusa/wiki/Configuration) |
| Layout, boot sequence, registry, state model | [Architecture](https://github.com/WhiteMuush/Medusa/wiki/Architecture) |
| Named contexts and isolation | [Environments](https://github.com/WhiteMuush/Medusa/wiki/Environments) |
| Per-tool details, ports, credentials | [SOC](https://github.com/WhiteMuush/Medusa/wiki/Tools-SOC) · [GRC](https://github.com/WhiteMuush/Medusa/wiki/Tools-GRC) · [Integration](https://github.com/WhiteMuush/Medusa/wiki/Tools-Integration) · [OT](https://github.com/WhiteMuush/Medusa/wiki/Tools-OT) |
| Default ports and collisions | [Ports Reference](https://github.com/WhiteMuush/Medusa/wiki/Ports-Reference) |
| Hardening notes | [Security](https://github.com/WhiteMuush/Medusa/wiki/Security) |
| Common problems | [Troubleshooting](https://github.com/WhiteMuush/Medusa/wiki/Troubleshooting) · [FAQ](https://github.com/WhiteMuush/Medusa/wiki/FAQ) |
| Add a tool, contribute | [Adding a Tool](https://github.com/WhiteMuush/Medusa/wiki/Adding-a-Tool) · [Contributing](https://github.com/WhiteMuush/Medusa/wiki/Contributing) |

## Modules

| # | Module | Tools | Scope |
|---|---|---|---|
| 1 | **SOC / Detection & Response** | 14 | SIEM, XDR, NDR, CTI, SOAR, endpoint and network forensics |
| 2 | **GRC / Governance & Compliance** | 5 | Risk, multi-framework compliance (ISO 27001, NIS2, DORA, GDPR), hardening, phishing |
| 3 | **Integration (IAM, Cloud, CI/CD)** | 11 | Identity, secrets, container/IaC/cloud scanning, SAST, DAST, secret detection |
| 4 | **OT / Industrial Security** | 5 | Passive ICS monitoring, SCADA asset mapping, OT vulnerability scanning |

## Available tools

### SOC / Detection & Response

- [**wazuh**](https://github.com/wazuh/wazuh-docker) `docker`, SIEM/XDR, detection, response, compliance
- [**security-onion**](https://github.com/Security-Onion-Solutions/securityonion) `vm`, NDR, network monitoring (Suricata + Zeek)
- [**suricata**](https://github.com/OISF/suricata) `docker`, high-performance network IDS/IPS
- [**zeek**](https://github.com/zeek/zeek) `docker`, passive network traffic analysis
- [**opencti**](https://github.com/OpenCTI-Platform/opencti) `docker`, CTI platform, threat intelligence
- [**misp**](https://github.com/MISP/misp-docker) `docker`, indicators of compromise sharing
- [**dfir-iris**](https://github.com/dfir-iris/iris-web) `docker`, case management, forensic investigation
- [**cortex**](https://github.com/TheHive-Project/Cortex) `docker`, observable enrichment and active response
- [**velociraptor**](https://github.com/Velocidex/velociraptor) `docker`, endpoint forensics and threat hunting
- [**shuffle**](https://github.com/Shuffle/Shuffle) `docker`, SOAR, orchestration and automation
- [**yara**](https://github.com/VirusTotal/yara) `cli`, malware detection rules
- [**grr**](https://github.com/google/grr) `docker`, remote incident response (Google)
- [**arkime**](https://github.com/arkime/arkime) `docker`, network packet capture and indexing
- [**sigma**](https://github.com/SigmaHQ/sigma) `cli`, generic multi-SIEM detection rules

### GRC / Governance & Compliance

- [**eramba**](https://github.com/eramba/docker) `docker`, GRC, policies, risks, compliance
- [**ciso-assistant**](https://github.com/intuitem/ciso-assistant-community) `docker`, lightweight GRC, multi-framework (NIS2, DORA, ISO 27001)
- [**simplerisk**](https://github.com/simplerisk/simplerisk) `docker`, risk management, registers and scoring
- [**openscap**](https://github.com/OpenSCAP/openscap) `cli`, compliance evaluation and system hardening
- [**gophish**](https://github.com/gophish/gophish) `docker`, phishing simulation and awareness

### Integration (IAM, Cloud, CI/CD)

- [**keycloak**](https://github.com/keycloak/keycloak) `docker`, IAM, SSO, MFA, identity federation
- [**teleport**](https://github.com/gravitational/teleport) `cli`, PAM, privileged access SSH/Kubernetes/DB
- [**vault**](https://github.com/hashicorp/vault) `docker`, secrets manager (dev mode)
- [**trivy**](https://github.com/aquasecurity/trivy) `cli`, container and IaC vulnerability scanner
- [**semgrep**](https://github.com/semgrep/semgrep) `cli`, SAST, static code analysis
- [**owasp-zap**](https://github.com/zaproxy/zaproxy) `docker`, DAST, web security scanner
- [**gitleaks**](https://github.com/gitleaks/gitleaks) `cli`, secret detection in Git repositories
- [**checkov**](https://github.com/bridgecrewio/checkov) `cli`, static IaC analysis (Terraform, Kubernetes)
- [**prowler**](https://github.com/prowler-cloud/prowler) `cli`, cloud security audit AWS/Azure/GCP
- [**scoutsuite**](https://github.com/nccgroup/ScoutSuite) `cli`, multi-cloud audit with HTML report
- [**falco**](https://github.com/falcosecurity/falco) `docker`, cloud-native runtime threat detection

### OT / Industrial Security

- [**malcolm**](https://github.com/cisagov/Malcolm) `cli`, OT network traffic analysis, industrial protocols (CISA)
- [**grfics**](https://github.com/Fortiphyd/GRFICSv2) `vm`, SCADA/ICS simulation for training labs
- [**nmap**](https://github.com/nmap/nmap) `cli`, network mapping and industrial NSE scripts
- [**openvas**](https://github.com/greenbone/openvas-scanner) `docker`, network vulnerability scanner
- [**grassmarlin**](https://github.com/nsacyber/GRASSMARLIN) `vm`, passive ICS/SCADA network mapping (NSA)

> `vm` tools print manual deployment instructions (ISO, VirtualBox/VMware), no automated deployment.

## Security

- Generated passwords use `openssl` (24 alphanumeric chars); each `credentials.txt` is `chmod 600`.
- Docker images are pinned to specific versions (Greenbone's feed images are the documented exception).
- Vault is deployed in **dev** mode, in-memory only, never for production.
- `medusa_deployments/` is git-ignored and must never be committed.
- Some tools ship fixed upstream default credentials (Wazuh, MISP, Eramba, OpenVAS), rotate them immediately.

Details and the full hardening checklist: [Security](https://github.com/WhiteMuush/Medusa/wiki/Security). Report vulnerabilities via [SECURITY.md](.github/SECURITY.md), not a public issue.

## Contributing

Contributions are welcome. The recipe to add a tool is [Adding a Tool](https://github.com/WhiteMuush/Medusa/wiki/Adding-a-Tool); workflow and conventions are in [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## License

[**MIT**](LICENSE)
