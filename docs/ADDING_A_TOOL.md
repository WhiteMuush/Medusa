# Adding a tool

The most common contribution. Picking the right pattern below — CLI vs
Docker — takes longer than writing the code.

## Decide the category and type

- **Category** — `soc`, `grc`, `integration`, `ot`. Pick the one whose
  description in the README's *Modules* section matches the tool. If
  it fits two, pick the one with the smaller current count.
- **Type** — `docker` (the tool ships a compose file or you can write
  a small one) or `cli` (a binary you install via apt / pip / curl).
  Choose `cli` only when the upstream doesn't provide a usable Docker
  image — most tools should be `docker`.

## The 5-line recipe

### CLI tool

```sh
# in lib/deploy_<category>.sh
deploy_foo() {
    log_message step "Installation de Foo (one-liner role)..."
    ensure_command_absent foo || return 0
    pip_install foo || { wait_enter; return 1; }     # or apt-get / curl
    mark_cli_installed "foo"
    show_access_info "Foo" \
        "Commande: foo" \
        "Usage:    foo --help"
    log_message success "Foo installe avec succes"
}
```

Then register it in `lib/core.sh` next to the existing entries:

```sh
register_tool "foo" "integration" "cli" "One-liner description shown in menu"
```

That's it. The interactive menu, the status dashboard, `medusa deploy foo`
and `medusa list integration` all pick it up automatically through the
registry and the `deploy_*` dispatcher.

### Docker tool

```sh
deploy_bar() {
    local dir
    dir=$(tool_dir "bar")
    mkdir -p "$dir"

    log_message step "Deploiement de Bar..."

    local admin_password
    admin_password=$(gen_password 16)

    cat > "${dir}/docker-compose.yml" << EOF
services:
  bar:
    image: barproject/bar:latest
    container_name: medusa-bar
    restart: unless-stopped
    ports:
      - "8086:80"
    environment:
      BAR_ADMIN_PASSWORD: ${admin_password}
    volumes:
      - ./data:/var/lib/bar
EOF

    mkdir -p "${dir}/data"
    compose_in_dir "$dir" up -d

    show_access_info "Bar" \
        "URL:      http://localhost:8086" \
        "User:     admin" \
        "Password: ${admin_password}"

    save_credentials "bar" \
        "URL: http://localhost:8086" \
        "Username: admin" \
        "Password: ${admin_password}"

    log_message success "Bar deploye avec succes"
}
```

And in `core.sh`:

```sh
register_tool "bar" "soc" "docker" "Short role-of-the-tool description"
```

### Tool that clones an upstream repo

When the upstream project publishes its own compose file, clone instead
of writing your own:

```sh
deploy_baz() {
    local dir
    dir=$(tool_dir "baz")

    log_message step "Deploiement de Baz..."
    git clone --depth 1 https://github.com/org/baz.git "$dir"

    [[ -f "${dir}/template.env" ]] && cp "${dir}/template.env" "${dir}/.env"
    compose_in_dir "$dir" up -d

    show_access_info "Baz" "URL: http://localhost:9000"
    log_message success "Baz deploye avec succes"
}
```

### Adding an interactive sub-menu (CLI tools only)

If your CLI tool benefits from a guided menu (think `yara`, `nmap`,
`trivy`), add a `run_<tool>` function in `lib/run_cli.sh`:

```sh
run_foo() {
    if ! command_exists foo; then
        log_message error "foo n'est pas installe — utilisez l'option Installer"
        wait_enter; return
    fi
    while true; do
        _run_menu "FOO" \
            "Scan rapide" \
            "Scan complet" \
            "Generer un rapport"
        [[ "${_run_choice,,}" == "b" ]] && return

        case "$_run_choice" in
            1)
                local target
                target=$(prompt_value "Cible" "127.0.0.1")
                foo --quick "$target"
                ;;
            2) ... ;;
            *) log_message error "Choix invalide"; sleep 1; continue ;;
        esac
        wait_enter
    done
}
```

No additional registration needed — `dispatch_run` resolves `run_<tool>`
the same way `dispatch_deploy` resolves `deploy_<tool>`.

## Don't / Do

| Don't                                                | Do                                                                       |
|------------------------------------------------------|--------------------------------------------------------------------------|
| `cd "$dir" && docker compose up -d`                  | `compose_in_dir "$dir" up -d`                                            |
| `echo -e "${RED}ERROR: ..."`                         | `log_message error "..."`                                                |
| Hardcode a password in the compose file              | `gen_password 16` + `save_credentials`                                   |
| Skip `mark_cli_installed` after a CLI install        | Always call it — that's how the dashboard knows the tool is present     |
| `docker compose up` without `-d`                     | Always `-d`, otherwise the menu loop blocks forever                      |
| Reuse a port already taken by another tool           | Check the *Ports* section of the README before picking                   |
| Use `read -p` directly for a value with a default    | `prompt_value "Label" "default"`                                         |
| `if [[ -f docker-compose.yml ]]; then ...` (no `$dir`) | `if [[ -f "${dir}/docker-compose.yml" ]]; then ...`                    |
| Add a CHANGELOG entry per PR                         | Describe the change in the PR body — release notes are bundled per tag   |
| Embed credentials in `show_access_info` _only_       | Also call `save_credentials` so they end up in `credentials.txt` chmod 600 |

## Checklist before opening the PR

```sh
bash -n medusa.sh lib/*.sh
shellcheck medusa.sh lib/*.sh
./medusa.sh list <your_category>     # your tool shows up
./medusa.sh deploy <your_tool>       # actually works
```

Update the README's *Outils disponibles* and *Ports par défaut* tables —
those are the parts contributors actually read.
