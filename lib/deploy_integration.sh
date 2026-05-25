# lib/deploy_integration.sh — Déploiement des outils Integration (IAM, Cloud, CI/CD)
# Sourcé par medusa.sh — ne pas exécuter directement
# shellcheck shell=bash
[[ -n "${_DEPLOY_INTEGRATION_SH_LOADED:-}" ]] && return 0
_DEPLOY_INTEGRATION_SH_LOADED=1

deploy_keycloak() {
    local dir
    dir=$(tool_dir "keycloak")
    mkdir -p "$dir"

    log_message "step" "Deploiement de Keycloak (IAM)..."

    local admin_password
    admin_password=$(gen_password 16)

    cat > "${dir}/docker-compose.yml" << EOF
services:
  keycloak-db:
    image: postgres:16-alpine
    container_name: medusa-keycloak-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: ${admin_password}
    volumes:
      - db_data:/var/lib/postgresql/data

  keycloak:
    image: quay.io/keycloak/keycloak:26.2
    container_name: medusa-keycloak
    restart: unless-stopped
    depends_on:
      - keycloak-db
    ports:
      - "8180:8080"
    environment:
      KC_DB: postgres
      KC_DB_URL_HOST: keycloak-db
      KC_DB_URL_DATABASE: keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: ${admin_password}
      KC_BOOTSTRAP_ADMIN_USERNAME: admin
      KC_BOOTSTRAP_ADMIN_PASSWORD: ${admin_password}
    command: start-dev

volumes:
  db_data:
EOF

    compose_in_dir "$dir" up -d

    show_access_info "Keycloak" \
        "URL:       http://localhost:8180" \
        "Console:   http://localhost:8180/admin" \
        "Admin:     admin" \
        "Password:  ${admin_password}"

    save_credentials "keycloak" \
        "URL: http://localhost:8180" \
        "Username: admin" \
        "Password: ${admin_password}"

    log_message "success" "Keycloak deploye avec succes"
}

deploy_vault() {
    local dir
    dir=$(tool_dir "vault")
    mkdir -p "$dir"

    log_message "step" "Deploiement de HashiCorp Vault (secrets manager)..."

    local root_token
    root_token="medusa-$(gen_password 16)"

    cat > "${dir}/docker-compose.yml" << EOF
services:
  vault:
    image: hashicorp/vault:latest
    container_name: medusa-vault
    restart: unless-stopped
    cap_add:
      - IPC_LOCK
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: ${root_token}
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    volumes:
      - ./data:/vault/data
      - ./config:/vault/config
EOF

    mkdir -p "${dir}/data" "${dir}/config"
    compose_in_dir "$dir" up -d

    log_message "warning" "Mode DEV : donnees en memoire uniquement — a ne pas utiliser en production"

    show_access_info "Vault" \
        "URL:       http://localhost:8200" \
        "Token:     ${root_token}" \
        "Mode:      DEV (donnees non persistees)" \
        "CLI:       export VAULT_ADDR=http://localhost:8200"

    save_credentials "vault" \
        "URL: http://localhost:8200" \
        "Root Token: ${root_token}" \
        "WARNING: Dev mode - donnees perdues au restart"

    log_message "success" "Vault deploye avec succes"
}

deploy_trivy() {
    log_message "step" "Installation de Trivy (scanner vulnerabilites)..."
    ensure_command_absent trivy || return 0

    local _trivy_installer
    _trivy_installer=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
        -o "$_trivy_installer" || { log_message "error" "Telechargement du script Trivy echoue"; rm -f "$_trivy_installer"; wait_enter; return 1; }
    sh "$_trivy_installer" -b /usr/local/bin || { log_message "error" "Installation de Trivy echouee"; rm -f "$_trivy_installer"; wait_enter; return 1; }
    rm -f "$_trivy_installer"

    mark_cli_installed "trivy"

    show_access_info "Trivy" \
        "Commande:  trivy" \
        "Image:     trivy image <image:tag>" \
        "Filesystem: trivy fs <path>" \
        "IaC:       trivy config <path>"

    log_message "success" "Trivy installe avec succes"
}

deploy_semgrep() {
    log_message "step" "Installation de Semgrep (SAST)..."
    ensure_command_absent semgrep || return 0
    pip_install semgrep || { wait_enter; return 1; }
    mark_cli_installed "semgrep"

    show_access_info "Semgrep" \
        "Commande:  semgrep" \
        "Scan:      semgrep --config auto <path>" \
        "OWASP:     semgrep --config p/owasp-top-ten <path>"

    log_message "success" "Semgrep installe avec succes"
}

deploy_owasp_zap() {
    local dir
    dir=$(tool_dir "owasp-zap")
    mkdir -p "$dir"

    log_message "step" "Deploiement d'OWASP ZAP (DAST)..."

    cat > "${dir}/docker-compose.yml" << 'EOF'
services:
  zap:
    image: zaproxy/zap-stable:latest
    container_name: medusa-owasp-zap
    ports:
      - "8090:8090"
    volumes:
      - ./data:/zap/wrk
    command: zap-webswing.sh
EOF

    mkdir -p "${dir}/data"
    compose_in_dir "$dir" up -d

    show_access_info "OWASP ZAP" \
        "URL:       http://localhost:8090/zap/" \
        "Baseline:  docker exec medusa-owasp-zap zap-baseline.py -t <url>" \
        "Full:      docker exec medusa-owasp-zap zap-full-scan.py -t <url>"

    log_message "success" "OWASP ZAP deploye avec succes"
}

deploy_gitleaks() {
    log_message "step" "Installation de Gitleaks (detection secrets Git)..."
    ensure_command_absent gitleaks || return 0

    local arch os latest_url
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="x64" ;;
        aarch64) arch="arm64" ;;
    esac
    os=$(uname -s | tr '[:upper:]' '[:lower:]')

    latest_url=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest \
        | grep -oP "https://[^\"]*/gitleaks_[\d.]+_${os}_${arch}\.tar\.gz" | head -1)

    if [[ -n "$latest_url" ]]; then
        curl -sL "$latest_url" | tar xz -C /usr/local/bin gitleaks
        chmod +x /usr/local/bin/gitleaks
    elif command_exists go; then
        go install github.com/zricethezav/gitleaks/v8@latest
    else
        log_message "error" "Impossible d'installer Gitleaks"
        wait_enter
        return 1
    fi

    mark_cli_installed "gitleaks"

    show_access_info "Gitleaks" \
        "Commande:  gitleaks" \
        "Detect:    gitleaks detect -s <path>" \
        "Protect:   gitleaks protect --staged"

    log_message "success" "Gitleaks installe avec succes"
}

deploy_checkov() {
    log_message "step" "Installation de Checkov (analyse IaC)..."
    ensure_command_absent checkov || return 0
    pip_install checkov || { wait_enter; return 1; }
    mark_cli_installed "checkov"

    show_access_info "Checkov" \
        "Commande:  checkov" \
        "Terraform: checkov -d <tf_dir>" \
        "Docker:    checkov -f <Dockerfile>"

    log_message "success" "Checkov installe avec succes"
}

deploy_prowler() {
    log_message "step" "Installation de Prowler (audit cloud)..."
    ensure_command_absent prowler || return 0
    pip_install prowler || { wait_enter; return 1; }
    mark_cli_installed "prowler"

    show_access_info "Prowler" \
        "Commande:  prowler" \
        "AWS:       prowler aws" \
        "Azure:     prowler azure" \
        "GCP:       prowler gcp"

    log_message "success" "Prowler installe avec succes"
}

deploy_scoutsuite() {
    log_message "step" "Installation de ScoutSuite (audit multi-cloud)..."
    ensure_command_absent scout || return 0
    pip_install scoutsuite || { wait_enter; return 1; }
    mark_cli_installed "scoutsuite"

    show_access_info "ScoutSuite" \
        "Commande:  scout" \
        "AWS:       scout aws" \
        "Azure:     scout azure --cli"

    log_message "success" "ScoutSuite installe avec succes"
}

deploy_falco() {
    local dir
    dir=$(tool_dir "falco")
    mkdir -p "$dir"

    log_message "step" "Deploiement de Falco (detection runtime cloud-native)..."

    cat > "${dir}/docker-compose.yml" << 'EOF'
services:
  falco:
    image: falcosecurity/falco:latest
    container_name: medusa-falco
    restart: unless-stopped
    privileged: true
    volumes:
      - /var/run/docker.sock:/host/var/run/docker.sock
      - /dev:/host/dev
      - /proc:/host/proc:ro
      - /boot:/host/boot:ro
      - /lib/modules:/host/lib/modules:ro
      - /usr:/host/usr:ro
      - /etc:/host/etc:ro
      - ./config:/etc/falco
      - ./rules:/etc/falco/rules.d
EOF

    mkdir -p "${dir}/config" "${dir}/rules"
    compose_in_dir "$dir" up -d

    show_access_info "Falco" \
        "Mode:      Daemon (pas d'interface web)" \
        "Logs:      ${COMPOSE_CMD} logs -f falco" \
        "Rules:     ${dir}/rules/"

    log_message "success" "Falco deploye avec succes"
}

deploy_teleport() {
    log_message "step" "Installation de Teleport (PAM)..."
    ensure_command_absent teleport || return 0

    local _teleport_installer
    _teleport_installer=$(mktemp)
    curl -fsSL https://goteleport.com/static/install.sh \
        -o "$_teleport_installer" || { log_message "error" "Telechargement du script Teleport echoue"; rm -f "$_teleport_installer"; wait_enter; return 1; }
    bash "$_teleport_installer" || { log_message "error" "Installation de Teleport echouee"; rm -f "$_teleport_installer"; wait_enter; return 1; }
    rm -f "$_teleport_installer"

    mark_cli_installed "teleport"

    show_access_info "Teleport" \
        "Commande:  teleport" \
        "Config:    teleport configure -o ${dir}/teleport.yaml" \
        "Ports:     3023 (SSH), 3080 (web)"

    log_message "success" "Teleport installe avec succes"
}
