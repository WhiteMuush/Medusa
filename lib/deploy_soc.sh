# lib/deploy_soc.sh — Déploiement des outils SOC / Detection & Response
# Sourcé par medusa.sh — ne pas exécuter directement
[[ -n "${_DEPLOY_SOC_SH_LOADED:-}" ]] && return 0
_DEPLOY_SOC_SH_LOADED=1

deploy_wazuh() {
    local dir
    dir=$(tool_dir "wazuh")
    if is_tool_installed "wazuh"; then
        log_message "warning" "Wazuh est deja installe dans ${dir}"
        confirm "Reinstaller ?" || return 0
        docker_remove "wazuh"
    fi

    log_message "step" "Deploiement de Wazuh (SIEM/XDR)..."
    log_message "info" "Clonage du depot officiel wazuh-docker..."
    git clone --depth 1 https://github.com/wazuh/wazuh-docker.git "$dir"

    local run_dir="${dir}"
    [[ -d "${dir}/single-node" ]] && run_dir="${dir}/single-node"

    log_message "info" "Generation des certificats..."
    if [[ -f "${dir}/single-node/generate-indexer-certs.yml" ]]; then
        compose_in_dir "${dir}/single-node" -f generate-indexer-certs.yml run --rm generator
    fi

    log_message "info" "Demarrage des conteneurs (single-node)..."
    compose_in_dir "${run_dir}" up -d

    show_access_info "Wazuh" \
        "URL:       https://localhost:443" \
        "User:      admin" \
        "Password:  SecretPassword" \
        "API:       https://localhost:55000" \
        "Ports:     1514 (agent), 1515 (enroll), 514/udp (syslog)"

    save_credentials "wazuh" \
        "Dashboard: https://localhost:443" \
        "Username: admin" \
        "Password: SecretPassword" \
        "API: https://localhost:55000"

    log_message "success" "Wazuh deploye avec succes"
}

deploy_suricata() {
    local dir
    dir=$(tool_dir "suricata")
    mkdir -p "$dir"

    log_message "step" "Deploiement de Suricata (IDS/IPS)..."

    local iface
    iface=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -1)
    iface="${iface:-eth0}"
    # Sanitize : caractères YAML-safe uniquement
    iface=$(echo "$iface" | tr -cd 'a-zA-Z0-9_.-')
    log_message "info" "Interface reseau detectee: ${iface}"

    cat > "${dir}/docker-compose.yml" << EOF
services:
  suricata:
    image: jasonish/suricata:latest
    container_name: medusa-suricata
    restart: unless-stopped
    network_mode: host
    cap_add:
      - NET_ADMIN
      - SYS_NICE
      - NET_RAW
    volumes:
      - ./logs:/var/log/suricata
      - ./rules:/var/lib/suricata/rules
      - ./etc:/etc/suricata
    command: -i ${iface}
EOF

    mkdir -p "${dir}/logs" "${dir}/rules" "${dir}/etc"
    compose_in_dir "$dir" up -d

    show_access_info "Suricata" \
        "Mode:    host (interface ${iface})" \
        "Logs:    ${dir}/logs/" \
        "Rules:   ${dir}/rules/"

    log_message "success" "Suricata deploye avec succes"
}

deploy_zeek() {
    local dir
    dir=$(tool_dir "zeek")
    mkdir -p "$dir"

    log_message "step" "Deploiement de Zeek (analyse trafic reseau)..."

    local iface
    iface=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -1)
    iface="${iface:-eth0}"
    iface=$(echo "$iface" | tr -cd 'a-zA-Z0-9_.-')

    cat > "${dir}/docker-compose.yml" << 'EOF'
services:
  zeek:
    image: zeek/zeek:lts
    container_name: medusa-zeek
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./logs:/opt/zeek/logs
      - ./spool:/opt/zeek/spool
      - ./site:/opt/zeek/share/zeek/site
    command: zeekctl deploy
    cap_add:
      - NET_ADMIN
      - NET_RAW
EOF

    mkdir -p "${dir}/logs" "${dir}/spool" "${dir}/site"
    compose_in_dir "$dir" up -d

    show_access_info "Zeek" \
        "Mode:    host (interface ${iface})" \
        "Logs:    ${dir}/logs/"

    log_message "success" "Zeek deploye avec succes"
}

deploy_opencti() {
    local dir
    dir=$(tool_dir "opencti")
    mkdir -p "$dir"

    log_message "step" "Deploiement d'OpenCTI (Cyber Threat Intelligence)..."

    local admin_token admin_password rabbitmq_password minio_secret connector_export_id connector_import_id
    admin_token=$(gen_uuid)
    admin_password=$(gen_password 16)
    rabbitmq_password=$(gen_password 16)
    minio_secret=$(gen_password 24)
    connector_export_id=$(gen_uuid)
    connector_import_id=$(gen_uuid)

    cat > "${dir}/.env" << EOF
OPENCTI_ADMIN_EMAIL=admin@medusa.local
OPENCTI_ADMIN_PASSWORD=${admin_password}
OPENCTI_ADMIN_TOKEN=${admin_token}
OPENCTI_BASE_URL=http://localhost:8080
RABBITMQ_DEFAULT_USER=opencti
RABBITMQ_DEFAULT_PASS=${rabbitmq_password}
MINIO_ROOT_USER=opencti
MINIO_ROOT_PASSWORD=${minio_secret}
ELASTIC_MEMORY_SIZE=4G
CONNECTOR_EXPORT_FILE_STIX_ID=${connector_export_id}
CONNECTOR_IMPORT_FILE_STIX_ID=${connector_import_id}
SMTP_HOSTNAME=localhost
EOF

    cat > "${dir}/docker-compose.yml" << 'EOF'
services:
  redis:
    image: redis:7
    container_name: medusa-opencti-redis
    restart: unless-stopped
    volumes:
      - redis_data:/data

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.15.3
    container_name: medusa-opencti-es
    restart: unless-stopped
    environment:
      - discovery.type=single-node
      - xpack.ml.enabled=false
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms${ELASTIC_MEMORY_SIZE:-4G} -Xmx${ELASTIC_MEMORY_SIZE:-4G}"
    volumes:
      - es_data:/usr/share/elasticsearch/data
    ulimits:
      memlock:
        soft: -1
        hard: -1

  minio:
    image: minio/minio:latest
    container_name: medusa-opencti-minio
    restart: unless-stopped
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    volumes:
      - minio_data:/data
    command: server /data

  rabbitmq:
    image: rabbitmq:3-management
    container_name: medusa-opencti-rabbitmq
    restart: unless-stopped
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_DEFAULT_USER}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_DEFAULT_PASS}
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

  opencti:
    image: opencti/platform:6
    container_name: medusa-opencti-platform
    restart: unless-stopped
    depends_on:
      - redis
      - elasticsearch
      - minio
      - rabbitmq
    ports:
      - "8080:8080"
    environment:
      - NODE_OPTIONS=--max-old-space-size=8096
      - APP__PORT=8080
      - APP__BASE_URL=${OPENCTI_BASE_URL}
      - APP__ADMIN__EMAIL=${OPENCTI_ADMIN_EMAIL}
      - APP__ADMIN__PASSWORD=${OPENCTI_ADMIN_PASSWORD}
      - APP__ADMIN__TOKEN=${OPENCTI_ADMIN_TOKEN}
      - APP__APP_LOGS__LOGS_LEVEL=error
      - REDIS__HOSTNAME=redis
      - REDIS__PORT=6379
      - ELASTICSEARCH__URL=http://elasticsearch:9200
      - MINIO__ENDPOINT=minio
      - MINIO__PORT=9000
      - MINIO__USE_SSL=false
      - MINIO__ACCESS_KEY=${MINIO_ROOT_USER}
      - MINIO__SECRET_KEY=${MINIO_ROOT_PASSWORD}
      - RABBITMQ__HOSTNAME=rabbitmq
      - RABBITMQ__PORT=5672
      - RABBITMQ__USERNAME=${RABBITMQ_DEFAULT_USER}
      - RABBITMQ__PASSWORD=${RABBITMQ_DEFAULT_PASS}
      - SMTP__HOSTNAME=${SMTP_HOSTNAME}
      - SMTP__PORT=25

  worker:
    image: opencti/worker:6
    container_name: medusa-opencti-worker
    restart: unless-stopped
    depends_on:
      - opencti
    environment:
      - OPENCTI_URL=http://opencti:8080
      - OPENCTI_TOKEN=${OPENCTI_ADMIN_TOKEN}
      - WORKER_LOG_LEVEL=info

  connector-export-file-stix:
    image: opencti/connector-export-file-stix:6
    container_name: medusa-opencti-export-stix
    restart: unless-stopped
    depends_on:
      - opencti
    environment:
      - OPENCTI_URL=http://opencti:8080
      - OPENCTI_TOKEN=${OPENCTI_ADMIN_TOKEN}
      - CONNECTOR_ID=${CONNECTOR_EXPORT_FILE_STIX_ID}
      - CONNECTOR_TYPE=INTERNAL_EXPORT_FILE
      - CONNECTOR_NAME=ExportFileStix2
      - CONNECTOR_SCOPE=application/json
      - CONNECTOR_LOG_LEVEL=info

  connector-import-file-stix:
    image: opencti/connector-import-file-stix:6
    container_name: medusa-opencti-import-stix
    restart: unless-stopped
    depends_on:
      - opencti
    environment:
      - OPENCTI_URL=http://opencti:8080
      - OPENCTI_TOKEN=${OPENCTI_ADMIN_TOKEN}
      - CONNECTOR_ID=${CONNECTOR_IMPORT_FILE_STIX_ID}
      - CONNECTOR_TYPE=INTERNAL_IMPORT_FILE
      - CONNECTOR_NAME=ImportFileStix2
      - CONNECTOR_VALIDATE_BEFORE_IMPORT=true
      - CONNECTOR_SCOPE=application/json,text/xml
      - CONNECTOR_AUTO=true
      - CONNECTOR_LOG_LEVEL=info

volumes:
  redis_data:
  es_data:
  minio_data:
  rabbitmq_data:
EOF

    compose_in_dir "$dir" up -d

    show_access_info "OpenCTI" \
        "URL:       http://localhost:8080" \
        "Email:     admin@medusa.local" \
        "Password:  ${admin_password}" \
        "Token:     ${admin_token}"

    save_credentials "opencti" \
        "URL: http://localhost:8080" \
        "Email: admin@medusa.local" \
        "Password: ${admin_password}" \
        "Token: ${admin_token}"

    log_message "success" "OpenCTI deploye avec succes"
}

deploy_misp() {
    local dir
    dir=$(tool_dir "misp")

    log_message "step" "Deploiement de MISP (Threat Intelligence Sharing)..."
    log_message "info" "Clonage du depot officiel misp-docker..."
    git clone --depth 1 https://github.com/MISP/misp-docker.git "$dir"

    [[ -f "${dir}/template.env" ]] && cp "${dir}/template.env" "${dir}/.env"

    log_message "info" "Demarrage des conteneurs MISP..."
    $COMPOSE_CMD up -d

    show_access_info "MISP" \
        "URL:       https://localhost:443" \
        "Email:     admin@admin.test" \
        "Password:  admin" \
        "!! Changez le mot de passe immediatement !!"

    save_credentials "misp" \
        "URL: https://localhost:443" \
        "Email: admin@admin.test" \
        "Default Password: admin"

    log_message "success" "MISP deploye avec succes"
}

deploy_dfir_iris() {
    local dir
    dir=$(tool_dir "dfir-iris")

    log_message "step" "Deploiement de DFIR-IRIS (Investigation forensique)..."
    git clone --depth 1 https://github.com/dfir-iris/iris-web.git "$dir"

    [[ -f "${dir}/.env.model" ]] && cp "${dir}/.env.model" "${dir}/.env"

    $COMPOSE_CMD up -d

    show_access_info "DFIR-IRIS" \
        "URL:       https://localhost:4433" \
        "User:      administrator" \
        "Password:  (voir logs du premier demarrage)" \
        "Logs:      cd ${dir} && ${COMPOSE_CMD} logs app | grep password"

    log_message "success" "DFIR-IRIS deploye avec succes"
}

deploy_cortex() {
    local dir
    dir=$(tool_dir "cortex")
    mkdir -p "$dir"

    log_message "step" "Deploiement de Cortex (Enrichissement & Response)..."

    cat > "${dir}/docker-compose.yml" << 'EOF'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.17.25
    container_name: medusa-cortex-es
    restart: unless-stopped
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
    volumes:
      - es_data:/usr/share/elasticsearch/data
    ulimits:
      memlock:
        soft: -1
        hard: -1

  cortex:
    image: thehiveproject/cortex:3.1.8
    container_name: medusa-cortex
    restart: unless-stopped
    depends_on:
      - elasticsearch
    ports:
      - "9001:9001"
    volumes:
      - ./jobs:/tmp/cortex-jobs
    environment:
      - job_directory=/tmp/cortex-jobs

volumes:
  es_data:
EOF

    mkdir -p "${dir}/jobs"
    compose_in_dir "$dir" up -d

    show_access_info "Cortex" \
        "URL:       http://localhost:9001" \
        "Setup:     Creez le compte admin au premier acces"

    log_message "success" "Cortex deploye avec succes"
}

deploy_velociraptor() {
    local dir
    dir=$(tool_dir "velociraptor")
    mkdir -p "$dir"

    log_message "step" "Deploiement de Velociraptor (Forensique endpoint)..."

    cat > "${dir}/docker-compose.yml" << 'EOF'
services:
  velociraptor:
    image: velociraptor/velociraptor:latest
    container_name: medusa-velociraptor
    restart: unless-stopped
    ports:
      - "8889:8889"
      - "8000:8000"
    volumes:
      - ./data:/velociraptor
      - ./config:/etc/velociraptor
EOF

    mkdir -p "${dir}/data" "${dir}/config"
    compose_in_dir "$dir" up -d

    show_access_info "Velociraptor" \
        "URL:       https://localhost:8889" \
        "GUI:       port 8889" \
        "Frontend:  port 8000 (agents)"

    log_message "success" "Velociraptor deploye avec succes"
}

deploy_shuffle() {
    local dir
    dir=$(tool_dir "shuffle")

    log_message "step" "Deploiement de Shuffle (SOAR)..."
    git clone --depth 1 https://github.com/Shuffle/Shuffle.git "$dir"

    compose_in_dir "$dir" up -d

    show_access_info "Shuffle" \
        "URL:       http://localhost:3443" \
        "Setup:     Creez le compte admin au premier acces"

    log_message "success" "Shuffle deploye avec succes"
}

deploy_grr() {
    local dir
    dir=$(tool_dir "grr")
    mkdir -p "$dir"

    log_message "step" "Deploiement de GRR Rapid Response..."

    # Port 8001 pour le GUI (evite conflit avec OpenCTI sur 8080)
    cat > "${dir}/docker-compose.yml" << 'EOF'
services:
  grr-server:
    image: ghcr.io/google/grr:v3.4.7.1
    container_name: medusa-grr
    restart: unless-stopped
    ports:
      - "8001:8000"
      - "8010:8080"
    volumes:
      - ./data:/var/grr-data
EOF

    mkdir -p "${dir}/data"
    compose_in_dir "$dir" up -d

    show_access_info "GRR Rapid Response" \
        "URL:       http://localhost:8001" \
        "Admin:     http://localhost:8010"

    log_message "success" "GRR deploye avec succes"
}

deploy_arkime() {
    local dir
    dir=$(tool_dir "arkime")
    mkdir -p "$dir"

    log_message "step" "Deploiement d'Arkime (capture paquets reseau)..."

    local iface
    iface=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -1)
    iface="${iface:-eth0}"
    iface=$(echo "$iface" | tr -cd 'a-zA-Z0-9_.-')

    cat > "${dir}/docker-compose.yml" << EOF
services:
  opensearch:
    image: opensearchproject/opensearch:2
    container_name: medusa-arkime-os
    restart: unless-stopped
    environment:
      - discovery.type=single-node
      - DISABLE_SECURITY_PLUGIN=true
      - "OPENSEARCH_JAVA_OPTS=-Xms2g -Xmx2g"
    volumes:
      - os_data:/usr/share/opensearch/data
    ulimits:
      memlock:
        soft: -1
        hard: -1

  arkime:
    image: ghcr.io/arkime/arkime/arkime:v5-latest
    container_name: medusa-arkime
    restart: unless-stopped
    depends_on:
      - opensearch
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    environment:
      - ARKIME_ELASTICSEARCH=http://localhost:9200
      - ARKIME_INTERFACE=${iface}
    volumes:
      - ./pcap:/opt/arkime/raw
      - ./config:/opt/arkime/etc

volumes:
  os_data:
EOF

    mkdir -p "${dir}/pcap" "${dir}/config"
    compose_in_dir "$dir" up -d

    show_access_info "Arkime" \
        "URL:       http://localhost:8005" \
        "Interface: ${iface}" \
        "PCAPs:     ${dir}/pcap/"

    log_message "success" "Arkime deploye avec succes"
}

deploy_yara() {
    log_message "step" "Installation de Yara (regles detection malwares)..."
    ensure_command_absent yara || return 0

    if command_exists apt-get; then
        apt-get update -qq && apt-get install -y -qq yara
    elif command_exists yum; then
        yum install -y yara
    elif command_exists dnf; then
        dnf install -y yara
    else
        log_message "error" "Gestionnaire de paquets non supporte"
        wait_enter
        return 1
    fi

    mark_cli_installed "yara"
    local dir
    dir=$(tool_dir "yara")

    log_message "info" "Telechargement des regles community..."
    git clone --depth 1 https://github.com/Yara-Rules/rules.git "${dir}/community-rules" 2>/dev/null || true

    show_access_info "Yara" \
        "Commande:  yara" \
        "Regles:    ${dir}/community-rules/" \
        "Usage:     yara <rule.yar> <fichier>"

    log_message "success" "Yara installe avec succes"
}

deploy_sigma() {
    log_message "step" "Installation de Sigma (regles de detection generiques)..."
    ensure_command_absent sigma || return 0
    pip_install sigma-cli pySigma || { wait_enter; return 1; }
    mark_cli_installed "sigma"

    local dir
    dir=$(tool_dir "sigma")
    git clone --depth 1 https://github.com/SigmaHQ/sigma.git "${dir}/sigma-rules" 2>/dev/null || true

    show_access_info "Sigma" \
        "Commande:  sigma" \
        "Regles:    ${dir}/sigma-rules/" \
        "Convert:   sigma convert -t <backend> -p <pipeline> <rule.yml>"

    log_message "success" "Sigma installe avec succes"
}

deploy_security_onion() {
    echo ""
    ui_rule
    echo -e "  ${BOLD}Security Onion${RESET} ${DIM}- Installation manuelle requise${RESET}"
    ui_rule
    echo ""
    echo -e "  Security Onion est une distribution complete (ISO)"
    echo -e "  et ne se deploie pas via Docker Compose."
    echo ""
    echo -e "  ${CYAN}Download:${RESET}  https://github.com/Security-Onion-Solutions/securityonion"
    echo -e "  ${CYAN}Docs:${RESET}      https://docs.securityonion.net/"
    echo ""
    echo -e "  ${DIM}Deploiement: ISO dediee, VM, ou OVA${RESET}"
    echo -e "  ${DIM}Prerequis: 16GB RAM, 4 CPU, 200GB disque${RESET}"
}
