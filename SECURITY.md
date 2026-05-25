# Security Policy

## Scope

Medusa is an **orchestrator**. It does not implement security primitives
itself — it wraps Docker Compose stacks, CLI installers, and a few helper
functions around 35 upstream open-source security tools.

That means there are two distinct disclosure paths:

| Vulnerability is in...                              | Report to...                                    |
|-----------------------------------------------------|-------------------------------------------------|
| The wrapper itself (Medusa code, compose templates) | This project — see "Reporting" below            |
| An upstream tool (Wazuh, OpenCTI, Suricata, ...)    | That tool's own security policy / disclosure    |

Examples of what's **in scope** for this project:

- Command injection or unsafe `eval` / unquoted expansion in `medusa.sh`,
  `lib/*.sh`
- A generated `docker-compose.yml` that exposes a service on `0.0.0.0`
  when it should be `127.0.0.1`, or sets a weak default password
- A `credentials.txt` written without `chmod 600`
- Path traversal in the `ENV_NAME` handling
- Curl-based installers that don't verify the source

Examples of what's **out of scope**:

- A CVE in Wazuh, MISP, OpenCTI, etc. — open an issue with the upstream
- "Falco runs as privileged" — that is by design and documented in the
  compose file, file an issue if you want to discuss the trade-off
- Vault is in dev mode by default — also intentional and warned about in
  the deploy output and the README

## Reporting

**Do not open a public GitHub issue for security reports.**

Use GitHub Security Advisories instead — it lets us discuss privately,
prepare a fix, and coordinate disclosure:

[**→ Report a vulnerability**](https://github.com/WhiteMuush/Medusa/security/advisories/new)

If you cannot use Security Advisories, contact the maintainer through the
email listed on their GitHub profile.

## What to include

- A description of the vulnerability and its impact
- Steps to reproduce (ideally a minimal `./medusa.sh ...` invocation or
  a diff)
- The Medusa version / commit hash
- Your suggested fix, if you have one

## Response expectations

This is a personal open-source project, so response times are best-effort.
Expect an acknowledgement within a few days, and a proposed fix or
disclosure timeline within a couple of weeks for confirmed issues.

## Supported versions

Only the `main` branch and the latest tagged release receive fixes.
There is no LTS branch.
