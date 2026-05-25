# Architecture

A 10-minute tour of how Medusa is laid out and why.

## Layout

```
medusa/
├── medusa.sh                  Entry point. Loads lib/ in order, then
│                              dispatches `menu` (default) or one of the
│                              CLI subcommands (deploy / start / stop / ...).
├── lib/
│   ├── core.sh                Colors, globals, registry of tools, generic
│                              Docker helpers (docker_up/down/restart/...),
│                              install primitives (compose_in_dir,
│                              ensure_command_absent, mark_cli_installed),
│                              prompt helpers (prompt_value, prompt_yesno).
│   ├── modules.sh             Interactive menu rendering, status
│                              dashboard, "start all" / "stop all",
│                              environment selection at startup.
│   ├── run_cli.sh             Sub-menus for CLI tools (yara, sigma,
│                              trivy, semgrep, nmap, prowler, ...) —
│                              dispatched by `run_<tool>`.
│   ├── deploy_soc.sh          14 SOC tool deployers (Wazuh, OpenCTI,
│                              MISP, Cortex, Velociraptor, ...).
│   ├── deploy_grc.sh          5 GRC tool deployers (Eramba, SimpleRisk,
│                              CISO Assistant, OpenSCAP, GoPhish).
│   ├── deploy_integration.sh  11 Integration deployers (Keycloak, Vault,
│                              Trivy, Semgrep, OWASP ZAP, ...).
│   └── deploy_ot.sh           5 OT deployers (Malcolm, OpenVAS, Nmap,
│                              GRFICSv2, GRASSMARLIN).
└── medusa_deployments/        Generated at runtime. One sub-directory
    └── <env_name>/            per environment, then one per tool with
        └── <tool>/            its compose file, .env, credentials.txt
            ├── docker-compose.yml
            ├── .env
            └── credentials.txt   (chmod 600)
```

## Boot sequence

1. `medusa.sh` resolves its own absolute path into `MEDUSA_HOME`.
   This is then used as the anchor for `BASE_DIR`, so every helper
   that builds a path (`tool_dir`, the deployers) gets an **absolute**
   path. Without this anchor, a `cd` deep inside the menu loop would
   silently break every subsequent relative path.
2. The seven `lib/` files are sourced in dependency order:
   `core` → `deploy_soc` → `deploy_grc` → `deploy_integration` → `deploy_ot` → `run_cli` → `modules`.
   Each has a `_LOADED` guard, so accidental double-sourcing is a no-op.
3. `main "$@"` reads `argv[0]` to decide between interactive menu mode
   (`menu` / empty) and the CLI subcommands (`deploy`, `start`, `stop`,
   `status`, `logs`, `remove`, `list`, `check`, `version`, `help`).

## Tool registry

Every tool lives in a single `register_tool` call inside `core.sh`:

```sh
register_tool "wazuh" "soc" "docker" "SIEM/XDR - Detection, reponse, conformite"
#               name   cat   type     description
```

Three parallel associative arrays — `TOOL_DESC`, `TOOL_CAT`, `TOOL_TYPE` — are
populated. Everything that needs to iterate tools (menu, dashboard, "start
all", `list` CLI) reads from these.

`type` is one of:

- `docker` — the deployer writes a `docker-compose.yml` (or clones an
  upstream repo that contains one) and runs `docker compose up -d`
- `cli` — the deployer installs a CLI binary (`apt`, `pip`, `curl | sh`,
  `go install`) and marks the tool installed with `mark_cli_installed`
- `vm` — instructions only, no automation (Security Onion ISO,
  GRASSMARLIN Java jar, GRFICSv2 lab)

## Dispatchers

Two simple dispatchers, both in `core.sh` / `run_cli.sh`:

```sh
dispatch_deploy() {
    local func="deploy_${1//-/_}"
    declare -f "$func" >/dev/null && "$func" \
        || log_message error "no deployer for $1"
}

dispatch_run() {
    local func="run_${1//-/_}"
    declare -f "$func" >/dev/null && "$func" \
        || log_message error "no run menu for $1"
}
```

This is what makes the "add a tool in 5 lines" pattern work — you only
need to define `deploy_<tool>` (and optionally `run_<tool>`) and add a
`register_tool` line. Nothing else has to be wired up.

## State model

A tool is in one of these states (see `get_tool_status` in `core.sh`):

- `not_installed` — no marker file, no binary on PATH
- `cli_installed` — marker file `.installed` exists or `command -v <tool>` succeeds
- `installed` — Docker tool with a compose file but no running container
- `running` — Docker tool with at least one container reporting `Up`
- `stopped` — Docker tool with a compose file but every container is down

The state determines which actions the per-tool menu offers
(Start/Stop/Logs for Docker, Run/Reinstall/Remove for CLI).

## Helpers — the contract

CLI installers are expected to use:

```sh
deploy_<tool>() {
    log_message step "Installing <tool>..."
    ensure_command_absent <bin> || return 0    # already installed → bail out
    <package manager / curl / pip command>
    mark_cli_installed "<tool>"
    show_access_info "<tool>" "Commande: <bin>" "..."
}
```

Docker deployers should never `cd` directly — they use `compose_in_dir`
to run inside the tool directory without leaking the working directory:

```sh
deploy_<tool>() {
    local dir
    dir=$(tool_dir "<tool>")
    mkdir -p "$dir"
    cat > "${dir}/docker-compose.yml" <<'EOF'
    ...
    EOF
    compose_in_dir "$dir" up -d
    show_access_info ...
}
```

## Environment isolation

`ENV_NAME` separates contexts. Each environment has its own deployment
tree under `medusa_deployments/<env_name>/`, so a "lab_soc" environment
and an "audit_client_X" environment never share compose files, volumes,
or credentials. In CLI mode the variable is set via the shell:

```sh
ENV_NAME=audit_client_X ./medusa.sh deploy keycloak
```

In interactive mode it is asked once at startup (new / existing /
auto-generated).

## Where things are NOT

- No database, no state file. The filesystem under `medusa_deployments/`
  is the source of truth.
- No background daemon. Medusa is invoked, does its thing, exits.
- No abstraction over Docker engines other than detecting whether
  `docker compose` (plugin) or `docker-compose` (legacy) is on PATH.

## Adding a tool

See [`ADDING_A_TOOL.md`](ADDING_A_TOOL.md) — that's the 5-minute recipe.
