# lib/deploy_ot.sh — Deployment of OT / Industrial Security tools
# Sourced by medusa.sh — do not execute directly
# shellcheck shell=bash
[[ -n "${_DEPLOY_OT_SH_LOADED:-}" ]] && return 0
_DEPLOY_OT_SH_LOADED=1

deploy_malcolm() {
    local dir
    dir=$(tool_dir "malcolm")

    log_message "step" "Deploying Malcolm (OT network traffic analysis - CISA)..."
    git clone --depth 1 https://github.com/cisagov/Malcolm.git "$dir"

    touch "${dir}/.installed"

    log_message "info" "Installing Malcolm Python dependencies..."
    pip_install "ruamel.yaml" "python-dotenv" 2>/dev/null || true
    # apt fallback for Debian/Ubuntu externally-managed environments
    apt-get install -y -qq python3-ruamel.yaml python3-dotenv 2>/dev/null || true

    show_access_info "Malcolm" \
        "Config:    python3 ${dir}/scripts/install.py" \
        "Start:     python3 ${dir}/scripts/start.py" \
        "Protocols: Modbus, DNP3, BACnet, EtherNet/IP, S7comm" \
        "Includes:  Suricata + Zeek + Arkime"

    log_message "success" "Malcolm cloned. Run the configuration script from the menu."
}

deploy_nmap() {
    log_message "step" "Installing Nmap (network mapping)..."
    ensure_command_absent nmap || return 0

    if command_exists apt-get; then
        apt-get update -qq && apt-get install -y -qq nmap
    elif command_exists yum; then
        yum install -y nmap
    elif command_exists dnf; then
        dnf install -y nmap
    else
        log_message "error" "Unsupported package manager"
        wait_enter
        return 1
    fi

    mark_cli_installed "nmap"

    show_access_info "Nmap" \
        "Command:   nmap" \
        "Scan:      nmap -sV -sC <target>" \
        "OT:        nmap --script modbus-discover <target>"

    log_message "success" "Nmap installed successfully"
}

deploy_openvas() {
    local dir
    dir=$(tool_dir "openvas")
    mkdir -p "$dir"

    log_message "step" "Deploying Greenbone/OpenVAS (vulnerability scanner)..."

    cat > "${dir}/docker-compose.yml" << 'EOF'
services:
  vulnerability-tests:
    image: greenbone/vulnerability-tests:latest
    container_name: medusa-openvas-vt
    volumes:
      - vt_data:/mnt

  notus-data:
    image: greenbone/notus-data:latest
    container_name: medusa-openvas-notus-data
    volumes:
      - notus_data:/mnt

  scap-data:
    image: greenbone/scap-data:latest
    container_name: medusa-openvas-scap
    volumes:
      - scap_data:/mnt

  cert-bund-data:
    image: greenbone/cert-bund-data:latest
    container_name: medusa-openvas-cert-bund
    volumes:
      - cert_data:/mnt

  dfn-cert-data:
    image: greenbone/dfn-cert-data:latest
    container_name: medusa-openvas-dfn-cert
    volumes:
      - cert_data:/mnt

  data-objects:
    image: greenbone/data-objects:latest
    container_name: medusa-openvas-data-objects
    volumes:
      - data_objects:/mnt

  report-formats:
    image: greenbone/report-formats:latest
    container_name: medusa-openvas-report-formats
    volumes:
      - data_objects:/mnt

  gpg-data:
    image: greenbone/gpg-data:latest
    container_name: medusa-openvas-gpg
    volumes:
      - gpg_data:/mnt

  redis-server:
    image: greenbone/redis-server:latest
    container_name: medusa-openvas-redis
    restart: unless-stopped
    volumes:
      - redis_socket:/run/redis

  pg-gvm:
    image: greenbone/pg-gvm:stable
    container_name: medusa-openvas-pg
    restart: unless-stopped
    volumes:
      - psql_data:/var/lib/postgresql
      - psql_socket:/var/run/postgresql

  gvmd:
    image: greenbone/gvmd:stable
    container_name: medusa-openvas-gvmd
    restart: unless-stopped
    depends_on:
      - pg-gvm
      - redis-server
    volumes:
      - gvmd_data:/var/lib/gvm
      - vt_data:/var/lib/openvas/plugins
      - scap_data:/var/lib/gvm/scap-data
      - cert_data:/var/lib/gvm/cert-data
      - data_objects:/var/lib/gvm/data-objects/gvmd
      - psql_socket:/var/run/postgresql
      - gvmd_socket:/run/gvmd
      - ospd_socket:/run/ospd

  gsa:
    image: greenbone/gsa:stable
    container_name: medusa-openvas-gsa
    restart: unless-stopped
    depends_on:
      - gvmd
    ports:
      - "9392:80"
    volumes:
      - gvmd_socket:/run/gvmd

  ospd-openvas:
    image: greenbone/ospd-openvas:stable
    container_name: medusa-openvas-ospd
    restart: unless-stopped
    depends_on:
      - redis-server
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - vt_data:/var/lib/openvas/plugins
      - notus_data:/var/lib/notus
      - ospd_socket:/run/ospd
      - redis_socket:/run/redis
      - gpg_data:/etc/openvas/gnupg

  notus-scanner:
    image: greenbone/notus-scanner:stable
    container_name: medusa-openvas-notus
    restart: unless-stopped
    depends_on:
      - redis-server
    volumes:
      - notus_data:/var/lib/notus
      - redis_socket:/run/redis
      - gpg_data:/etc/openvas/gnupg

volumes:
  vt_data:
  notus_data:
  scap_data:
  cert_data:
  data_objects:
  gpg_data:
  redis_socket:
  psql_data:
  psql_socket:
  gvmd_data:
  gvmd_socket:
  ospd_socket:
EOF

    compose_in_dir "$dir" up -d

    log_message "warning" "First startup: feed download takes 30-60 minutes"

    show_access_info "Greenbone/OpenVAS" \
        "URL:       http://localhost:9392" \
        "User:      admin" \
        "Password:  admin (change it!)"

    save_credentials "openvas" \
        "URL: http://localhost:9392" \
        "Username: admin" \
        "Default Password: admin"

    log_message "success" "OpenVAS deployed successfully"
}

deploy_grfics() {
    echo ""
    ui_rule
    echo -e "  ${BOLD}GRFICSv2${RESET} ${DIM}- Manual installation required${RESET}"
    ui_rule
    echo ""
    echo -e "  ICS/SCADA simulation environment (VMs)"
    echo ""
    echo -e "  ${CYAN}Repository:${RESET} https://github.com/Fortiphyd/GRFICSv2"
    echo -e "  ${CYAN}Requirements:${RESET} VirtualBox/VMware, 8GB+ RAM"
    echo -e "  ${DIM}Components: PLC (OpenPLC), HMI (ScadaBR)${RESET}"
}

deploy_grassmarlin() {
    echo ""
    ui_rule
    echo -e "  ${BOLD}GRASSMARLIN${RESET} ${DIM}- Manual installation required${RESET}"
    ui_rule
    echo ""
    echo -e "  Passive ICS/SCADA network mapping (NSA, Java)"
    echo ""
    echo -e "  ${CYAN}Repository:${RESET} https://github.com/nsacyber/GRASSMARLIN"
    echo -e "  ${CYAN}Requirements:${RESET} Java 8+"
    echo -e "  ${DIM}Launch: java -jar grassmarlin.jar${RESET}"
}
