# lib/deploy_grc.sh — Deployment of GRC / Governance & Compliance tools
# Sourced by medusa.sh — do not execute directly
# shellcheck shell=bash
[[ -n "${_DEPLOY_GRC_SH_LOADED:-}" ]] && return 0
_DEPLOY_GRC_SH_LOADED=1

deploy_eramba() {
    local dir
    dir=$(tool_dir "eramba")

    log_message "step" "Deploying Eramba Community (GRC)..."
    log_message "info" "Cloning official eramba/docker repository..."
    git clone --depth 1 https://github.com/eramba/docker.git "$dir"

    if [[ -f "${dir}/docker-compose.yml" ]]; then
        compose_in_dir "$dir" up -d
    else
        log_message "error" "Unexpected repository structure — check ${dir}"
        return 1
    fi

    show_access_info "Eramba" \
        "URL:       https://localhost:8443" \
        "User:      admin@eramba.org" \
        "Password:  admin (change it!)" \
        "Docs:      https://github.com/eramba/docker"

    save_credentials "eramba" \
        "URL: https://localhost:8443" \
        "User: admin@eramba.org" \
        "Default Password: admin"

    log_message "success" "Eramba deployed successfully"
}

deploy_ciso_assistant() {
    local dir
    dir=$(tool_dir "ciso-assistant")

    log_message "step" "Deploying CISO Assistant (multi-framework GRC)..."
    git clone --depth 1 https://github.com/intuitem/ciso-assistant-community.git "$dir"

    if [[ -f "${dir}/docker-compose.yml" ]]; then
        compose_in_dir "$dir" up -d
    elif [[ -d "${dir}/docker" ]]; then
        compose_in_dir "${dir}/docker" up -d
    fi

    show_access_info "CISO Assistant" \
        "URL:       http://localhost:8443" \
        "Setup:     Create the admin account on first access" \
        "Frameworks: NIS2, DORA, ISO 27001, NIST CSF"

    log_message "success" "CISO Assistant deployed successfully"
}

deploy_simplerisk() {
    local dir
    dir=$(tool_dir "simplerisk")
    mkdir -p "$dir"

    log_message "step" "Deploying SimpleRisk (Risk management)..."

    local db_password
    db_password=$(gen_password 16)

    cat > "${dir}/docker-compose.yml" << EOF
services:
  simplerisk-db:
    image: mariadb:10.11
    container_name: medusa-simplerisk-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${db_password}
      MYSQL_DATABASE: simplerisk
      MYSQL_USER: simplerisk
      MYSQL_PASSWORD: ${db_password}
    volumes:
      - db_data:/var/lib/mysql

  simplerisk:
    image: simplerisk/simplerisk:20260519-001
    container_name: medusa-simplerisk
    restart: unless-stopped
    depends_on:
      - simplerisk-db
    ports:
      - "8085:80"
      - "8445:443"
    environment:
      SIMPLERISK_DB_HOSTNAME: simplerisk-db
      SIMPLERISK_DB_PORT: 3306
      SIMPLERISK_DB_USERNAME: simplerisk
      SIMPLERISK_DB_PASSWORD: ${db_password}

volumes:
  db_data:
EOF

    compose_in_dir "$dir" up -d

    show_access_info "SimpleRisk" \
        "URL:       https://localhost:8445" \
        "Setup:     Admin account created during initial setup"

    save_credentials "simplerisk" \
        "URL: https://localhost:8445" \
        "DB Password: ${db_password}"

    log_message "success" "SimpleRisk deployed successfully"
}

deploy_openscap() {
    log_message "step" "Installing OpenSCAP (compliance evaluation)..."
    ensure_command_absent oscap || return 0

    if command_exists apt-get; then
        apt-get update -qq
        # libopenscap8 (Debian 11/Ubuntu 22) renamed to libopenscap25 (Debian 12+/Ubuntu 24+)
        local oscap_lib="libopenscap8"
        if ! apt-cache show libopenscap8 &>/dev/null 2>&1; then
            oscap_lib="libopenscap25"
        fi
        apt-get install -y -qq "$oscap_lib" openscap-scanner openscap-utils || true
        # scap-security-guide — package name varies by distro/version
        local ssg_installed=0
        for ssg_pkg in ssg-debian12 ssg-debian11 ssg-debian ssg-base scap-security-guide; do
            if apt-cache show "$ssg_pkg" &>/dev/null 2>&1; then
                apt-get install -y -qq "$ssg_pkg" && ssg_installed=1 && break
            fi
        done
        if [[ $ssg_installed -eq 0 ]]; then
            log_message "warning" "scap-security-guide not available — datastreams must be provided manually"
        fi
    elif command_exists dnf; then
        dnf install -y openscap-scanner scap-security-guide openscap-utils
    elif command_exists yum; then
        yum install -y openscap-scanner scap-security-guide openscap-utils
    else
        log_message "error" "Unsupported package manager"
        wait_enter
        return 1
    fi

    mark_cli_installed "openscap"

    show_access_info "OpenSCAP" \
        "Command:   oscap" \
        "Profiles:  /usr/share/xml/scap/ssg/content/" \
        "Usage:     oscap xccdf eval --profile cis <datastream>"

    log_message "success" "OpenSCAP installed successfully"
}

deploy_gophish() {
    local dir
    dir=$(tool_dir "gophish")
    mkdir -p "$dir"

    log_message "step" "Deploying GoPhish (phishing simulation)..."

    cat > "${dir}/docker-compose.yml" << 'EOF'
services:
  gophish:
    image: gophish/gophish:0.12.1
    container_name: medusa-gophish
    restart: unless-stopped
    ports:
      - "3333:3333"
      - "8083:80"
    volumes:
      - ./data:/opt/gophish/data
EOF

    mkdir -p "${dir}/data"
    compose_in_dir "$dir" up -d

    sleep 1
    local init_pass
    init_pass=$(cd "$dir" && $COMPOSE_CMD logs gophish 2>&1 | grep -oP 'Please login with the username admin and the password \K\S+' || echo "(see logs)")

    show_access_info "GoPhish" \
        "Admin:     https://localhost:3333" \
        "User:      admin" \
        "Password:  ${init_pass}" \
        "Phishing:  http://localhost:8083"

    save_credentials "gophish" \
        "Admin: https://localhost:3333" \
        "Username: admin" \
        "Initial Password: ${init_pass}"

    log_message "success" "GoPhish deployed successfully"
}
