# lib/run_cli.sh — Sous-menus de lancement des outils CLI
# shellcheck shell=bash
# Sourcé par medusa.sh — ne pas exécuter directement
# shellcheck shell=bash
[[ -n "${_RUN_CLI_SH_LOADED:-}" ]] && return 0
_RUN_CLI_SH_LOADED=1

# ============================================================================
# DISPATCHER
# ============================================================================

dispatch_run() {
    local tool="$1"
    local func="run_${tool//-/_}"

    if declare -f "$func" &>/dev/null; then
        $func
    else
        log_message "error" "Pas de sous-menu defini pour ${tool}"
        wait_enter
    fi
}

# ============================================================================
# HELPER — saisie de paramètre optionnel
# ============================================================================

_check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_message "warning" "Cette operation necessite les droits root (sudo)"
        echo ""
        read -rp "  ${YELLOW}[?]${RESET} Relancer avec sudo ? [o/N]: " _sudo_reply
        if [[ "${_sudo_reply,,}" =~ ^[oy]$ ]]; then
            exec sudo "$0" "$@"
        fi
        return 1
    fi
    return 0
}

_check_docker_registry() {
    local registry="$1"
    log_message "info" "Registry privee detectee : ${registry}"
    echo ""
    read -rp "  ${YELLOW}[?]${RESET} Authentification requise ? [o/N]: " _reg_reply
    if [[ "${_reg_reply,,}" =~ ^[oy]$ ]]; then
        local user pass
        user=$(_prompt "Username" "")
        pass=$(_prompt "Password" "")
        echo "$pass" | docker login "$registry" -u "$user" --password-stdin
    fi
}

_prompt() {
    local label="$1" default="$2" value
    read -rp "  ${CYAN}${label}${RESET} [${DIM}${default}${RESET}]: " value
    echo "${value:-$default}"
}

_run_menu() {
    local title="$1"
    shift
    clear_screen
    display_header
    echo -e "${BRIGHT_GREEN}│"
    echo -e "╞─> ${BRIGHT_MAGENTA}${BOLD}${title}${RESET}"
    echo -e "${BRIGHT_GREEN}│"
    echo -e "${BRIGHT_GREEN}╰─╮"
    local i=1
    for label in "$@"; do
        echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}${i}${RESET}  ${label}"
        ((i++))
    done
    echo -e "${BRIGHT_GREEN}╭─╯"
    echo -e "${BRIGHT_GREEN}│"
    echo -e "${BRIGHT_GREEN}╞─────────────╮"
    echo -e "${BRIGHT_GREEN}│ ${RED}B${RESET}  Retour ${BRIGHT_GREEN}  │"
    echo -e "${BRIGHT_GREEN}╞─────────────╯"
    echo -e "${BRIGHT_GREEN}│"
    echo -e "${BRIGHT_GREEN}◉"
    echo ""
    read -rp "  > " _run_choice
}

# ============================================================================
# SOC
# ============================================================================

run_yara() {
    if ! command_exists yara; then
        log_message "error" "yara n'est pas installe — utilisez l'option Installer"
        wait_enter; return
    fi
    while true; do
        _run_menu "YARA" \
            "Scanner un fichier" \
            "Scanner un repertoire" \
            "Tester une regle"
        [[ "${_run_choice,,}" == "b" ]] && return

        local rules_dir rules_default
        rules_dir="$(tool_dir yara)/community-rules"
        if [[ -d "${rules_dir}/malware" ]]; then
            rules_default="${rules_dir}/malware/"
        else
            rules_default="/path/to/rules.yar"
        fi
        echo ""
        case "$_run_choice" in
            1)
                local target rule
                target=$(_prompt "Fichier cible" "/path/to/file")
                rule=$(_prompt "Fichier de regles (.yar)" "${rules_default}")
                echo ""
                yara "$rule" "$target"
                ;;
            2)
                local target rule
                target=$(_prompt "Repertoire cible" "/path/to/dir")
                rule=$(_prompt "Fichier de regles (.yar)" "${rules_default}")
                echo ""
                yara -r "$rule" "$target"
                ;;
            3)
                local rule test_file
                rule=$(_prompt "Fichier de regles (.yar)" "${rules_default}")
                test_file=$(_prompt "Fichier de test" "/path/to/sample")
                echo ""
                yara -s "$rule" "$test_file"
                ;;
            *) log_message "error" "Choix invalide"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_sigma() {
    if ! command_exists sigma; then
        log_message "error" "sigma-cli n'est pas installe — utilisez l'option Installer"
        wait_enter; return
    fi
    while true; do
        _run_menu "SIGMA" \
            "Convertir une regle (Elastic)" \
            "Convertir une regle (Splunk)" \
            "Convertir une regle (Wazuh)" \
            "Valider une regle" \
            "Lister les backends disponibles"
        [[ "${_run_choice,,}" == "b" ]] && return

        local rules_dir rules_default
        rules_dir="$(tool_dir sigma)/sigma-rules"
        if [[ -d "${rules_dir}/rules" ]]; then
            rules_default="${rules_dir}/rules/"
        else
            rules_default="/path/to/rule.yml"
        fi
        echo ""
        case "$_run_choice" in
            1)
                local rule
                rule=$(_prompt "Fichier regle (.yml)" "${rules_default}")
                echo ""
                sigma convert -t elasticsearch -p ecs-windows "$rule"
                ;;
            2)
                local rule
                rule=$(_prompt "Fichier regle (.yml)" "${rules_default}")
                echo ""
                sigma convert -t splunk "$rule"
                ;;
            3)
                local rule
                rule=$(_prompt "Fichier regle (.yml)" "${rules_default}")
                echo ""
                sigma convert -t wazuh "$rule"
                ;;
            4)
                local rule
                rule=$(_prompt "Fichier regle (.yml)" "${rules_default}")
                echo ""
                sigma check "$rule"
                ;;
            5)
                echo ""
                sigma list-targets
                ;;
            *) log_message "error" "Choix invalide"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

# ============================================================================
# GRC
# ============================================================================

# Détecte le premier profil correspondant à un mot-clé dans le datastream courant
# Usage : _oscap_find_profile "cis"  →  stocke dans OSCAP_PROFILE
_oscap_find_profile() {
    local keyword="$1"
    OSCAP_PROFILE=""
    if [[ -z "$OSCAP_DS" || ! -f "$OSCAP_DS" ]]; then return 1; fi

    # oscap info liste les profils sous la forme "Profile ID: ..."
    local match
    match=$(oscap info "$OSCAP_DS" 2>/dev/null \
        | grep -i "Profile ID:" \
        | grep -i "$keyword" \
        | head -1 \
        | sed 's/.*Profile ID:[[:space:]]*//')

    if [[ -n "$match" ]]; then
        OSCAP_PROFILE="$match"
        log_message "info" "Profil selectionne : ${OSCAP_PROFILE}"
    else
        log_message "warning" "Aucun profil '${keyword}' trouve dans ce datastream"
        log_message "info" "Profils disponibles :"
        oscap info "$OSCAP_DS" 2>/dev/null | grep "Profile ID:" | sed 's/.*Profile ID:[[:space:]]*/  - /' || true
        echo ""
        read -rp "  ${CYAN}ID du profil${RESET}: " OSCAP_PROFILE
    fi
}

# Stocke le chemin dans OSCAP_DS (variable globale) pour éviter la subshell
# Affiche les messages sur stderr — ne pas appeler via $(...)
_oscap_detect_ds() {
    OSCAP_DS=""
    local ssg_dir="/usr/share/xml/scap/ssg/content"

    if [[ -d "$ssg_dir" ]]; then
        local distro version
        distro=$(grep -oP '(?<=^ID=).+' /etc/os-release 2>/dev/null | tr -d '"')
        version=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release 2>/dev/null | tr -d '"' | tr -d '.')

        for candidate in \
            "${ssg_dir}/ssg-${distro}${version}-ds.xml" \
            "${ssg_dir}/ssg-${distro}-ds.xml" \
            "${ssg_dir}/ssg-debian12-ds.xml" \
            "${ssg_dir}/ssg-debian11-ds.xml" \
            "${ssg_dir}/ssg-ubuntu2404-ds.xml" \
            "${ssg_dir}/ssg-ubuntu2204-ds.xml"
        do
            if [[ -f "$candidate" ]]; then
                OSCAP_DS="$candidate"
                break
            fi
        done
    fi

    if [[ -z "$OSCAP_DS" ]]; then
        log_message "warning" "Aucun datastream SSG detecte automatiquement"
        log_message "info" "Datastreams disponibles :"
        find /usr/share/xml /usr/share/openscap -name "*-ds.xml" 2>/dev/null | head -10 || true
        echo ""
        read -rp "  ${CYAN}Chemin du datastream${RESET} [${DIM}/path/to/ds.xml${RESET}]: " OSCAP_DS
        OSCAP_DS="${OSCAP_DS:-}"
    else
        log_message "info" "Datastream detecte : ${OSCAP_DS}"
    fi
}

run_openscap() {
    while true; do
        _run_menu "OPENSCAP" \
            "Scan conformite CIS" \
            "Scan conformite STIG" \
            "Scan personnalise" \
            "Generer rapport HTML" \
            "Lister les profils disponibles"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                _check_root || { wait_enter; continue; }
                _oscap_detect_ds
                [[ -z "$OSCAP_DS" || ! -f "$OSCAP_DS" ]] && { log_message "error" "Datastream introuvable"; wait_enter; continue; }
                _oscap_find_profile "cis"
                [[ -z "$OSCAP_PROFILE" ]] && { wait_enter; continue; }
                echo ""
                oscap xccdf eval --profile "$OSCAP_PROFILE" \
                    --results /tmp/oscap-results.xml "$OSCAP_DS"
                ;;
            2)
                _check_root || { wait_enter; continue; }
                _oscap_detect_ds
                [[ -z "$OSCAP_DS" || ! -f "$OSCAP_DS" ]] && { log_message "error" "Datastream introuvable"; wait_enter; continue; }
                _oscap_find_profile "stig"
                [[ -z "$OSCAP_PROFILE" ]] && { wait_enter; continue; }
                echo ""
                oscap xccdf eval --profile "$OSCAP_PROFILE" \
                    --results /tmp/oscap-results.xml "$OSCAP_DS"
                ;;
            3)
                _check_root || { wait_enter; continue; }
                _oscap_detect_ds
                [[ -z "$OSCAP_DS" || ! -f "$OSCAP_DS" ]] && { log_message "error" "Datastream introuvable"; wait_enter; continue; }
                log_message "info" "Profils disponibles :"
                oscap info "$OSCAP_DS" 2>/dev/null | grep "Profile ID:" | sed 's/.*Profile ID:[[:space:]]*/  - /' || true
                echo ""
                local profile
                read -rp "  ${CYAN}ID du profil${RESET}: " profile
                [[ -z "$profile" ]] && { log_message "error" "Profil requis"; wait_enter; continue; }
                echo ""
                oscap xccdf eval --profile "$profile" --results /tmp/oscap-results.xml "$OSCAP_DS"
                ;;
            4)
                if [[ -f /tmp/oscap-results.xml ]]; then
                    oscap xccdf generate report /tmp/oscap-results.xml > /tmp/oscap-report.html
                    log_message "success" "Rapport genere : /tmp/oscap-report.html"
                else
                    log_message "error" "Aucun resultat trouve, lancez d'abord un scan"
                fi
                ;;
            5)
                _oscap_detect_ds
                [[ -z "$OSCAP_DS" || ! -f "$OSCAP_DS" ]] && { log_message "error" "Datastream introuvable"; wait_enter; continue; }
                echo ""
                oscap info "$OSCAP_DS"
                ;;
            *) log_message "error" "Choix invalide"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

# ============================================================================
# INTEGRATION
# ============================================================================

run_trivy() {
    if ! command_exists trivy; then
        log_message "error" "trivy n'est pas installe — utilisez l'option Installer"
        wait_enter; return
    fi
    while true; do
        _run_menu "TRIVY" \
            "Scanner une image Docker" \
            "Scanner un repertoire (filesystem)" \
            "Scanner une config IaC" \
            "Scanner un depot Git" \
            "Generer rapport JSON"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                local image
                image=$(_prompt "Image" "nginx:latest")
                # Detecte registry privee (contient un . ou : avant le premier /)
                if [[ "$image" =~ ^[^/]*\.[^/]*/ ]] || [[ "$image" =~ ^[^/]*:[0-9]+/ ]]; then
                    _check_docker_registry "${image%%/*}"
                fi
                echo ""
                trivy image "$image"
                ;;
            2)
                local path
                path=$(_prompt "Chemin" ".")
                echo ""
                trivy fs "$path"
                ;;
            3)
                local path
                path=$(_prompt "Chemin IaC (Terraform, K8s...)" ".")
                echo ""
                trivy config "$path"
                ;;
            4)
                local repo
                repo=$(_prompt "URL du depot" "https://github.com/org/repo")
                echo ""
                trivy repo "$repo"
                ;;
            5)
                local image output
                image=$(_prompt "Image" "nginx:latest")
                output=$(_prompt "Fichier de sortie" "/tmp/trivy-report.json")
                echo ""
                trivy image -f json -o "$output" "$image"
                log_message "success" "Rapport sauvegarde : ${output}"
                ;;
            *) log_message "error" "Choix invalide"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_semgrep() {
    if ! command_exists semgrep; then
        log_message "error" "semgrep n'est pas installe — utilisez l'option Installer"
        wait_enter; return
    fi
    while true; do
        _run_menu "SEMGREP" \
            "Scan auto (regles recommandees)" \
            "Scan OWASP Top 10" \
            "Scan secrets" \
            "Scan sur un langage specifique" \
            "Generer rapport JSON"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                local path
                path=$(_prompt "Repertoire cible" ".")
                echo ""
                semgrep --config auto "$path"
                ;;
            2)
                local path
                path=$(_prompt "Repertoire cible" ".")
                echo ""
                semgrep --config p/owasp-top-ten "$path"
                ;;
            3)
                local path
                path=$(_prompt "Repertoire cible" ".")
                echo ""
                semgrep --config p/secrets "$path"
                ;;
            4)
                local path lang
                path=$(_prompt "Repertoire cible" ".")
                lang=$(_prompt "Langage (python, javascript, java...)" "python")
                echo ""
                semgrep --config "p/${lang}" "$path"
                ;;
            5)
                local path output
                path=$(_prompt "Repertoire cible" ".")
                output=$(_prompt "Fichier de sortie" "/tmp/semgrep-report.json")
                echo ""
                semgrep --config auto --json -o "$output" "$path"
                log_message "success" "Rapport sauvegarde : ${output}"
                ;;
            *) log_message "error" "Choix invalide"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_gitleaks() {
    if ! command_exists gitleaks; then
        log_message "error" "gitleaks n'est pas installe — utilisez l'option Installer"
        wait_enter; return
    fi
    while true; do
        _run_menu "GITLEAKS" \
            "Scanner le depot courant" \
            "Scanner un depot specifique" \
            "Scanner les fichiers stagees (pre-commit)" \
            "Scanner un depot distant (URL)" \
            "Generer rapport JSON"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                echo ""
                gitleaks detect -s .
                ;;
            2)
                local path
                path=$(_prompt "Chemin du depot" "/path/to/repo")
                echo ""
                gitleaks detect -s "$path"
                ;;
            3)
                echo ""
                gitleaks protect --staged
                ;;
            4)
                local url
                url=$(_prompt "URL du depot" "https://github.com/org/repo")
                echo ""
                gitleaks detect --source "$url"
                ;;
            5)
                local path output
                path=$(_prompt "Chemin du depot" ".")
                output=$(_prompt "Fichier de sortie" "/tmp/gitleaks-report.json")
                echo ""
                gitleaks detect -s "$path" --report-path "$output" --report-format json
                log_message "success" "Rapport sauvegarde : ${output}"
                ;;
            *) log_message "error" "Choix invalide"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_checkov() {
    if ! command_exists checkov; then
        log_message "error" "checkov n'est pas installe — utilisez l'option Installer"
        wait_enter; return
    fi
    while true; do
        _run_menu "CHECKOV" \
            "Scanner Terraform" \
            "Scanner Kubernetes (YAML)" \
            "Scanner un Dockerfile" \
            "Scanner CloudFormation" \
            "Generer rapport JSON"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                local path
                path=$(_prompt "Repertoire Terraform" ".")
                echo ""
                checkov -d "$path" --framework terraform
                ;;
            2)
                local path
                path=$(_prompt "Repertoire / fichier K8s" ".")
                echo ""
                checkov -d "$path" --framework kubernetes
                ;;
            3)
                local file
                file=$(_prompt "Chemin du Dockerfile" "./Dockerfile")
                echo ""
                checkov -f "$file" --framework dockerfile
                ;;
            4)
                local path
                path=$(_prompt "Repertoire CloudFormation" ".")
                echo ""
                checkov -d "$path" --framework cloudformation
                ;;
            5)
                local path output
                path=$(_prompt "Repertoire cible" ".")
                output=$(_prompt "Fichier de sortie" "/tmp/checkov-report.json")
                echo ""
                checkov -d "$path" -o json > "$output"
                log_message "success" "Rapport sauvegarde : ${output}"
                ;;
            *) log_message "error" "Choix invalide"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

_prowler_check_aws() {
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        if ! command_exists aws || ! aws sts get-caller-identity &>/dev/null 2>&1; then
            log_message "warning" "Credentials AWS non configures"
            echo -e "${BRIGHT_GREEN}│"
            echo -e "╞─> ${BRIGHT_MAGENTA}${BOLD}AUTHENTIFICATION AWS${RESET}"
            echo -e "${BRIGHT_GREEN}╰─╮"
            echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}1${RESET}  Variables d'environnement (saisie maintenant)"
            echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}2${RESET}  Profil AWS CLI (~/.aws/credentials)"
            echo -e "${BRIGHT_GREEN}  ╞─> ${RED}B${RESET}  Annuler"
            echo -e "${BRIGHT_GREEN}╭─╯"
            echo -e "${BRIGHT_GREEN}◉"
            echo ""
            read -rp "  > " _cred_choice
            case "${_cred_choice,,}" in
                1)
                    AWS_ACCESS_KEY_ID=$(_prompt "AWS_ACCESS_KEY_ID" "")
                    AWS_SECRET_ACCESS_KEY=$(_prompt "AWS_SECRET_ACCESS_KEY" "")
                    AWS_DEFAULT_REGION=$(_prompt "AWS_DEFAULT_REGION" "eu-west-1")
                    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION
                    ;;
                2)
                    local profile
                    profile=$(_prompt "Profil AWS CLI" "default")
                    export AWS_PROFILE="$profile"
                    ;;
                *) return 1 ;;
            esac
        fi
    fi
    return 0
}

_prowler_check_azure() {
    if [[ -z "${AZURE_CLIENT_ID:-}" ]]; then
        log_message "warning" "Credentials Azure non configures"
        echo -e "${BRIGHT_GREEN}│"
        echo -e "╞─> ${BRIGHT_MAGENTA}${BOLD}AUTHENTIFICATION AZURE${RESET}"
        echo -e "${BRIGHT_GREEN}╰─╮"
        echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}1${RESET}  Service Principal (variables d'environnement)"
        echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}2${RESET}  Azure CLI (az login deja effectue)"
        echo -e "${BRIGHT_GREEN}  ╞─> ${RED}B${RESET}  Annuler"
        echo -e "${BRIGHT_GREEN}╭─╯"
        echo -e "${BRIGHT_GREEN}◉"
        echo ""
        read -rp "  > " _cred_choice
        case "${_cred_choice,,}" in
            1)
                AZURE_CLIENT_ID=$(_prompt "AZURE_CLIENT_ID" "")
                AZURE_CLIENT_SECRET=$(_prompt "AZURE_CLIENT_SECRET" "")
                AZURE_TENANT_ID=$(_prompt "AZURE_TENANT_ID" "")
                AZURE_SUBSCRIPTION_ID=$(_prompt "AZURE_SUBSCRIPTION_ID" "")
                export AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID
                ;;
            2)
                log_message "info" "Utilisation d'Azure CLI (az login)"
                return 0
                ;;
            *) return 1 ;;
        esac
    fi
    return 0
}

_prowler_check_gcp() {
    if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
        if ! command_exists gcloud || ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
            log_message "warning" "Credentials GCP non configures"
            echo -e "${BRIGHT_GREEN}│"
            echo -e "╞─> ${BRIGHT_MAGENTA}${BOLD}AUTHENTIFICATION GCP${RESET}"
            echo -e "${BRIGHT_GREEN}╰─╮"
            echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}1${RESET}  Fichier de cle de compte de service (JSON)"
            echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}2${RESET}  gcloud CLI (gcloud auth deja effectue)"
            echo -e "${BRIGHT_GREEN}  ╞─> ${RED}B${RESET}  Annuler"
            echo -e "${BRIGHT_GREEN}╭─╯"
            echo -e "${BRIGHT_GREEN}◉"
            echo ""
            read -rp "  > " _cred_choice
            case "${_cred_choice,,}" in
                1)
                    GOOGLE_APPLICATION_CREDENTIALS=$(_prompt "Chemin vers le fichier JSON" "/path/to/key.json")
                    export GOOGLE_APPLICATION_CREDENTIALS
                    ;;
                2)
                    log_message "info" "Utilisation de gcloud CLI"
                    return 0
                    ;;
                *) return 1 ;;
            esac
        fi
    fi
    return 0
}

run_prowler() {
    if ! command_exists prowler; then
        log_message "error" "prowler n'est pas installe — utilisez l'option Installer"
        wait_enter; return
    fi
    while true; do
        _run_menu "PROWLER" \
            "Audit AWS" \
            "Audit Azure" \
            "Audit GCP" \
            "Lister les checks disponibles" \
            "Scan cible sur un service AWS" \
            "Generer rapport HTML"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                _prowler_check_aws || { wait_enter; continue; }
                echo ""
                prowler aws
                ;;
            2)
                _prowler_check_azure || { wait_enter; continue; }
                echo ""
                if [[ -n "${AZURE_CLIENT_ID:-}" ]]; then
                    prowler azure --sp-env-auth
                else
                    prowler azure --az-cli-auth
                fi
                ;;
            3)
                _prowler_check_gcp || { wait_enter; continue; }
                echo ""
                prowler gcp
                ;;
            4)
                local provider
                provider=$(_prompt "Provider (aws, azure, gcp)" "aws")
                echo ""
                prowler "$provider" --list-checks
                ;;
            5)
                _prowler_check_aws || { wait_enter; continue; }
                local service
                service=$(_prompt "Service (s3, iam, ec2...)" "s3")
                echo ""
                prowler aws --service "$service"
                ;;
            6)
                local provider output
                provider=$(_prompt "Provider (aws, azure, gcp)" "aws")
                output=$(_prompt "Dossier de sortie" "./output")
                case "$provider" in
                    aws)   _prowler_check_aws   || { wait_enter; continue; } ;;
                    azure) _prowler_check_azure || { wait_enter; continue; } ;;
                    gcp)   _prowler_check_gcp   || { wait_enter; continue; } ;;
                esac
                echo ""
                prowler "$provider" -M html -o "$output"
                log_message "success" "Rapport sauvegarde dans : ${output}"
                ;;
            *) log_message "error" "Choix invalide"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_scoutsuite() {
    if ! command_exists scout; then
        log_message "error" "scoutsuite n'est pas installe — utilisez l'option Installer"
        wait_enter; return
    fi
    while true; do
        _run_menu "SCOUTSUITE" \
            "Audit AWS" \
            "Audit Azure (CLI auth)" \
            "Audit GCP" \
            "Audit Azure (Service Principal)" \
            "Ouvrir le dernier rapport"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                _prowler_check_aws || { wait_enter; continue; }
                echo ""
                scout aws
                ;;
            2)
                log_message "info" "Assurez-vous d'avoir execute : az login"
                echo ""
                scout azure --cli
                ;;
            3)
                _prowler_check_gcp || { wait_enter; continue; }
                local project
                project=$(_prompt "GCP Project ID" "my-project")
                echo ""
                scout gcp --project-id "$project"
                ;;
            4)
                local tenant client secret
                [[ -z "${AZURE_TENANT_ID:-}" ]]     && tenant=$(_prompt "Tenant ID" "")      || tenant="$AZURE_TENANT_ID"
                [[ -z "${AZURE_CLIENT_ID:-}" ]]     && client=$(_prompt "Client ID" "")      || client="$AZURE_CLIENT_ID"
                [[ -z "${AZURE_CLIENT_SECRET:-}" ]] && secret=$(_prompt "Client Secret" "")  || secret="$AZURE_CLIENT_SECRET"
                echo ""
                scout azure --tenant "$tenant" --client-id "$client" --client-secret "$secret"
                ;;
            5)
                local report
                report=$(find . -name "scoutsuite-report*.html" 2>/dev/null | head -1)
                if [[ -n "$report" ]]; then
                    log_message "info" "Rapport : ${report}"
                    xdg-open "$report" 2>/dev/null || log_message "info" "Ouvrez manuellement : ${report}"
                else
                    log_message "warning" "Aucun rapport trouve dans le repertoire courant"
                fi
                ;;
            *) log_message "error" "Choix invalide"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_teleport() {
    if ! command_exists teleport; then
        log_message "error" "teleport n'est pas installe — utilisez l'option Installer"
        wait_enter; return
    fi
    while true; do
        _run_menu "TELEPORT" \
            "Generer la configuration" \
            "Demarrer le serveur" \
            "Afficher le statut" \
            "Creer un token d'invitation" \
            "Lister les noeuds connectes"
        [[ "${_run_choice,,}" == "b" ]] && return

        local dir
        dir=$(tool_dir teleport)
        echo ""
        case "$_run_choice" in
            1)
                local domain
                domain=$(_prompt "Domaine public" "localhost")
                echo ""
                teleport configure -o "${dir}/teleport.yaml" \
                    --cluster-name="$domain" \
                    --public-addr="${domain}:3080" 2>/dev/null \
                    || teleport configure > "${dir}/teleport.yaml"
                log_message "success" "Config generee : ${dir}/teleport.yaml"
                ;;
            2)
                local config
                config=$(_prompt "Fichier de config" "${dir}/teleport.yaml")
                if [[ ! -f "$config" ]]; then
                    log_message "error" "Fichier de configuration introuvable : ${config}"
                    log_message "info" "Utilisez l'option 1 pour generer la configuration d'abord"
                    wait_enter; continue
                fi
                echo ""
                teleport start --config="$config"
                ;;
            3)
                echo ""
                tctl status 2>/dev/null || teleport version
                ;;
            4)
                local token_type
                token_type=$(_prompt "Type (node, app, db)" "node")
                echo ""
                tctl tokens add --type="$token_type"
                ;;
            5)
                echo ""
                tctl nodes ls 2>/dev/null || log_message "warning" "Serveur Teleport non accessible"
                ;;
            *) log_message "error" "Choix invalide"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

# ============================================================================
# OT
# ============================================================================

run_malcolm() {
    local dir
    dir=$(tool_dir malcolm)

    if [[ ! -d "$dir" ]]; then
        log_message "error" "Malcolm non installe — utilisez l'option Installer depuis le menu"
        wait_enter
        return
    fi

    while true; do
        _run_menu "MALCOLM" \
            "Configurer (install.py)" \
            "Demarrer" \
            "Arreter" \
            "Statut" \
            "Logs"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                log_message "info" "Installation des dependances Python de Malcolm..."
                # Malcolm requiert ruamel.yaml et python-dotenv — installer avant install.py
                pip_install "ruamel.yaml" "python-dotenv" 2>/dev/null || true
                # Fallback apt si pip_install n'a pas suffi
                if ! python3 -c "import ruamel.yaml" 2>/dev/null; then
                    log_message "info" "Tentative via apt..."
                    apt-get install -y -qq python3-ruamel.yaml 2>/dev/null \
                        || log_message "warning" "ruamel.yaml non disponible via apt"
                fi
                if ! python3 -c "import dotenv" 2>/dev/null; then
                    apt-get install -y -qq python3-dotenv 2>/dev/null \
                        || log_message "warning" "python-dotenv non disponible via apt"
                fi
                log_message "info" "Lancement de la configuration Malcolm..."
                python3 "${dir}/scripts/install.py"
                ;;
            2)
                log_message "step" "Demarrage de Malcolm..."
                python3 "${dir}/scripts/start.py"
                ;;
            3)
                log_message "step" "Arret de Malcolm..."
                python3 "${dir}/scripts/stop.py" 2>/dev/null \
                    || (cd "$dir" && $COMPOSE_CMD down 2>/dev/null) \
                    || log_message "error" "Script d'arret introuvable"
                ;;
            4)
                python3 "${dir}/scripts/status.py" 2>/dev/null \
                    || (cd "$dir" && $COMPOSE_CMD ps 2>/dev/null) \
                    || log_message "warning" "Script de statut introuvable"
                ;;
            5)
                local svc
                svc=$(_prompt "Service (laisser vide = tous)" "")
                echo ""
                if [[ -n "$svc" ]]; then
                    compose_in_dir "$dir" logs --tail=100 "$svc" 2>/dev/null \
                        || log_message "error" "Service introuvable : ${svc}"
                else
                    compose_in_dir "$dir" logs --tail=50 2>/dev/null \
                        || log_message "error" "Compose non configure — lancez d'abord la configuration"
                fi
                ;;
            *) log_message "error" "Choix invalide"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_nmap() {
    if ! command_exists nmap; then
        log_message "error" "nmap n'est pas installe — utilisez l'option Installer"
        wait_enter; return
    fi
    while true; do
        _run_menu "NMAP" \
            "Scan rapide (top ports)" \
            "Scan complet avec scripts" \
            "Scan de detection de services" \
            "Scan OT / Modbus" \
            "Scan OT / BACnet" \
            "Scan furtif (SYN)" \
            "Generer rapport XML"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                local target
                target=$(_prompt "Cible (IP / plage)" "192.168.1.0/24")
                echo ""
                nmap -F "$target"
                ;;
            2)
                _check_root || { wait_enter; continue; }
                local target
                target=$(_prompt "Cible (IP / plage)" "192.168.1.0/24")
                echo ""
                nmap -sV -sC -O "$target"
                ;;
            3)
                local target
                target=$(_prompt "Cible (IP / plage)" "192.168.1.0/24")
                echo ""
                nmap -sV --version-intensity 5 "$target"
                ;;
            4)
                local target nse_dir="/usr/share/nmap/scripts"
                if [[ ! -f "${nse_dir}/modbus-discover.nse" ]]; then
                    log_message "warning" "Script modbus-discover absent — installez nmap-scripts ou une version recente de nmap"
                    wait_enter; continue
                fi
                target=$(_prompt "Cible (IP)" "192.168.1.100")
                echo ""
                nmap -p 502 --script modbus-discover "$target"
                ;;
            5)
                local target nse_dir="/usr/share/nmap/scripts"
                if [[ ! -f "${nse_dir}/bacnet-info.nse" ]]; then
                    log_message "warning" "Script bacnet-info absent — installez nmap-scripts ou une version recente de nmap"
                    wait_enter; continue
                fi
                target=$(_prompt "Cible (IP)" "192.168.1.100")
                echo ""
                nmap -p 47808 --script bacnet-info "$target"
                ;;
            6)
                _check_root || { wait_enter; continue; }
                local target
                target=$(_prompt "Cible (IP / plage)" "192.168.1.0/24")
                echo ""
                nmap -sS "$target"
                ;;
            7)
                local target output
                target=$(_prompt "Cible (IP / plage)" "192.168.1.0/24")
                output=$(_prompt "Fichier de sortie" "/tmp/nmap-scan.xml")
                echo ""
                nmap -sV -oX "$output" "$target"
                log_message "success" "Rapport sauvegarde : ${output}"
                ;;
            *) log_message "error" "Choix invalide"; sleep 1; continue ;;
        esac
        wait_enter
    done
}
