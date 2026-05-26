# lib/run_cli.sh — CLI tool launch sub-menus
# shellcheck shell=bash
# Sourced by medusa.sh — do not execute directly
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
        log_message "error" "No sub-menu defined for ${tool}"
        wait_enter
    fi
}

# ============================================================================
# HELPERS
# ============================================================================

_check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_message "warning" "This operation requires root privileges (sudo)"
        echo ""
        read -rp "  ${YELLOW}[?]${RESET} Relaunch with sudo? [y/N]: " _sudo_reply
        if [[ "${_sudo_reply,,}" =~ ^[oy]$ ]]; then
            exec sudo "$0"
        fi
        return 1
    fi
    return 0
}

_check_docker_registry() {
    local registry="$1"
    log_message "info" "Private registry detected: ${registry}"
    echo ""
    read -rp "  ${YELLOW}[?]${RESET} Authentication required? [y/N]: " _reg_reply
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
    echo -e "${BRIGHT_GREEN}│ ${RED}B${RESET}  Back   ${BRIGHT_GREEN}  │"
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
        log_message "error" "yara is not installed — use the Install option"
        wait_enter; return
    fi
    while true; do
        _run_menu "YARA" \
            "Scan a file" \
            "Scan a directory" \
            "Test a rule"
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
                target=$(_prompt "Target file" "/path/to/file")
                rule=$(_prompt "Rules file (.yar)" "${rules_default}")
                echo ""
                yara "$rule" "$target"
                ;;
            2)
                local target rule
                target=$(_prompt "Target directory" "/path/to/dir")
                rule=$(_prompt "Rules file (.yar)" "${rules_default}")
                echo ""
                yara -r "$rule" "$target"
                ;;
            3)
                local rule test_file
                rule=$(_prompt "Rules file (.yar)" "${rules_default}")
                test_file=$(_prompt "Test file" "/path/to/sample")
                echo ""
                yara -s "$rule" "$test_file"
                ;;
            *) log_message "error" "Invalid choice"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_sigma() {
    if ! command_exists sigma; then
        log_message "error" "sigma-cli is not installed — use the Install option"
        wait_enter; return
    fi
    while true; do
        _run_menu "SIGMA" \
            "Convert a rule (Elastic)" \
            "Convert a rule (Splunk)" \
            "Convert a rule (Wazuh)" \
            "Validate a rule" \
            "List available backends"
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
                rule=$(_prompt "Rule file (.yml)" "${rules_default}")
                echo ""
                sigma convert -t elasticsearch -p ecs-windows "$rule"
                ;;
            2)
                local rule
                rule=$(_prompt "Rule file (.yml)" "${rules_default}")
                echo ""
                sigma convert -t splunk "$rule"
                ;;
            3)
                local rule
                rule=$(_prompt "Rule file (.yml)" "${rules_default}")
                echo ""
                sigma convert -t wazuh "$rule"
                ;;
            4)
                local rule
                rule=$(_prompt "Rule file (.yml)" "${rules_default}")
                echo ""
                sigma check "$rule"
                ;;
            5)
                echo ""
                sigma list-targets
                ;;
            *) log_message "error" "Invalid choice"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

# ============================================================================
# GRC
# ============================================================================

# Finds the first profile matching a keyword in the current datastream
# Usage: _oscap_find_profile "cis"  →  stores result in OSCAP_PROFILE
_oscap_find_profile() {
    local keyword="$1"
    OSCAP_PROFILE=""
    if [[ -z "$OSCAP_DS" || ! -f "$OSCAP_DS" ]]; then return 1; fi

    # oscap info lists profiles as "Profile ID: ..."
    local match
    match=$(oscap info "$OSCAP_DS" 2>/dev/null \
        | grep -i "Profile ID:" \
        | grep -i "$keyword" \
        | head -1 \
        | sed 's/.*Profile ID:[[:space:]]*//')

    if [[ -n "$match" ]]; then
        OSCAP_PROFILE="$match"
        log_message "info" "Selected profile: ${OSCAP_PROFILE}"
    else
        log_message "warning" "No '${keyword}' profile found in this datastream"
        log_message "info" "Available profiles:"
        oscap info "$OSCAP_DS" 2>/dev/null | grep "Profile ID:" | sed 's/.*Profile ID:[[:space:]]*/  - /' || true
        echo ""
        read -rp "  ${CYAN}Profile ID${RESET}: " OSCAP_PROFILE
    fi
}

# Stores the path in OSCAP_DS (global variable) to avoid subshell issues
# Prints messages to stderr — do not call via $(...)
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
        log_message "warning" "No SSG datastream auto-detected"
        log_message "info" "Available datastreams:"
        find /usr/share/xml /usr/share/openscap -name "*-ds.xml" 2>/dev/null | head -10 || true
        echo ""
        read -rp "  ${CYAN}Datastream path${RESET} [${DIM}/path/to/ds.xml${RESET}]: " OSCAP_DS
        OSCAP_DS="${OSCAP_DS:-}"
    else
        log_message "info" "Detected datastream: ${OSCAP_DS}"
    fi
}

run_openscap() {
    while true; do
        _run_menu "OPENSCAP" \
            "CIS compliance scan" \
            "STIG compliance scan" \
            "Custom scan" \
            "Generate HTML report" \
            "List available profiles"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                _check_root || { wait_enter; continue; }
                _oscap_detect_ds
                [[ -z "$OSCAP_DS" || ! -f "$OSCAP_DS" ]] && { log_message "error" "Datastream not found"; wait_enter; continue; }
                _oscap_find_profile "cis"
                [[ -z "$OSCAP_PROFILE" ]] && { wait_enter; continue; }
                echo ""
                oscap xccdf eval --profile "$OSCAP_PROFILE" \
                    --results /tmp/oscap-results.xml "$OSCAP_DS"
                ;;
            2)
                _check_root || { wait_enter; continue; }
                _oscap_detect_ds
                [[ -z "$OSCAP_DS" || ! -f "$OSCAP_DS" ]] && { log_message "error" "Datastream not found"; wait_enter; continue; }
                _oscap_find_profile "stig"
                [[ -z "$OSCAP_PROFILE" ]] && { wait_enter; continue; }
                echo ""
                oscap xccdf eval --profile "$OSCAP_PROFILE" \
                    --results /tmp/oscap-results.xml "$OSCAP_DS"
                ;;
            3)
                _check_root || { wait_enter; continue; }
                _oscap_detect_ds
                [[ -z "$OSCAP_DS" || ! -f "$OSCAP_DS" ]] && { log_message "error" "Datastream not found"; wait_enter; continue; }
                log_message "info" "Available profiles:"
                oscap info "$OSCAP_DS" 2>/dev/null | grep "Profile ID:" | sed 's/.*Profile ID:[[:space:]]*/  - /' || true
                echo ""
                local profile
                read -rp "  ${CYAN}Profile ID${RESET}: " profile
                [[ -z "$profile" ]] && { log_message "error" "Profile required"; wait_enter; continue; }
                echo ""
                oscap xccdf eval --profile "$profile" --results /tmp/oscap-results.xml "$OSCAP_DS"
                ;;
            4)
                if [[ -f /tmp/oscap-results.xml ]]; then
                    oscap xccdf generate report /tmp/oscap-results.xml > /tmp/oscap-report.html
                    log_message "success" "Report generated: /tmp/oscap-report.html"
                else
                    log_message "error" "No results found, run a scan first"
                fi
                ;;
            5)
                _oscap_detect_ds
                [[ -z "$OSCAP_DS" || ! -f "$OSCAP_DS" ]] && { log_message "error" "Datastream not found"; wait_enter; continue; }
                echo ""
                oscap info "$OSCAP_DS"
                ;;
            *) log_message "error" "Invalid choice"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

# ============================================================================
# INTEGRATION
# ============================================================================

run_trivy() {
    if ! command_exists trivy; then
        log_message "error" "trivy is not installed — use the Install option"
        wait_enter; return
    fi
    while true; do
        _run_menu "TRIVY" \
            "Scan a Docker image" \
            "Scan a directory (filesystem)" \
            "Scan an IaC config" \
            "Scan a Git repository" \
            "Generate JSON report"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                local image
                image=$(_prompt "Image" "nginx:latest")
                # Detect private registry (contains a . or : before the first /)
                if [[ "$image" =~ ^[^/]*\.[^/]*/ ]] || [[ "$image" =~ ^[^/]*:[0-9]+/ ]]; then
                    _check_docker_registry "${image%%/*}"
                fi
                echo ""
                trivy image "$image"
                ;;
            2)
                local path
                path=$(_prompt "Path" ".")
                echo ""
                trivy fs "$path"
                ;;
            3)
                local path
                path=$(_prompt "IaC path (Terraform, K8s...)" ".")
                echo ""
                trivy config "$path"
                ;;
            4)
                local repo
                repo=$(_prompt "Repository URL" "https://github.com/org/repo")
                echo ""
                trivy repo "$repo"
                ;;
            5)
                local image output
                image=$(_prompt "Image" "nginx:latest")
                output=$(_prompt "Output file" "/tmp/trivy-report.json")
                echo ""
                trivy image -f json -o "$output" "$image"
                log_message "success" "Report saved: ${output}"
                ;;
            *) log_message "error" "Invalid choice"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_semgrep() {
    if ! command_exists semgrep; then
        log_message "error" "semgrep is not installed — use the Install option"
        wait_enter; return
    fi
    while true; do
        _run_menu "SEMGREP" \
            "Auto scan (recommended rules)" \
            "OWASP Top 10 scan" \
            "Secrets scan" \
            "Language-specific scan" \
            "Generate JSON report"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                local path
                path=$(_prompt "Target directory" ".")
                echo ""
                semgrep --config auto "$path"
                ;;
            2)
                local path
                path=$(_prompt "Target directory" ".")
                echo ""
                semgrep --config p/owasp-top-ten "$path"
                ;;
            3)
                local path
                path=$(_prompt "Target directory" ".")
                echo ""
                semgrep --config p/secrets "$path"
                ;;
            4)
                local path lang
                path=$(_prompt "Target directory" ".")
                lang=$(_prompt "Language (python, javascript, java...)" "python")
                echo ""
                semgrep --config "p/${lang}" "$path"
                ;;
            5)
                local path output
                path=$(_prompt "Target directory" ".")
                output=$(_prompt "Output file" "/tmp/semgrep-report.json")
                echo ""
                semgrep --config auto --json -o "$output" "$path"
                log_message "success" "Report saved: ${output}"
                ;;
            *) log_message "error" "Invalid choice"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_gitleaks() {
    if ! command_exists gitleaks; then
        log_message "error" "gitleaks is not installed — use the Install option"
        wait_enter; return
    fi
    while true; do
        _run_menu "GITLEAKS" \
            "Scan current repository" \
            "Scan a specific repository" \
            "Scan staged files (pre-commit)" \
            "Scan a remote repository (URL)" \
            "Generate JSON report"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                echo ""
                gitleaks detect -s .
                ;;
            2)
                local path
                path=$(_prompt "Repository path" "/path/to/repo")
                echo ""
                gitleaks detect -s "$path"
                ;;
            3)
                echo ""
                gitleaks protect --staged
                ;;
            4)
                local url
                url=$(_prompt "Repository URL" "https://github.com/org/repo")
                echo ""
                gitleaks detect --source "$url"
                ;;
            5)
                local path output
                path=$(_prompt "Repository path" ".")
                output=$(_prompt "Output file" "/tmp/gitleaks-report.json")
                echo ""
                gitleaks detect -s "$path" --report-path "$output" --report-format json
                log_message "success" "Report saved: ${output}"
                ;;
            *) log_message "error" "Invalid choice"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_checkov() {
    if ! command_exists checkov; then
        log_message "error" "checkov is not installed — use the Install option"
        wait_enter; return
    fi
    while true; do
        _run_menu "CHECKOV" \
            "Scan Terraform" \
            "Scan Kubernetes (YAML)" \
            "Scan a Dockerfile" \
            "Scan CloudFormation" \
            "Generate JSON report"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                local path
                path=$(_prompt "Terraform directory" ".")
                echo ""
                checkov -d "$path" --framework terraform
                ;;
            2)
                local path
                path=$(_prompt "K8s directory / file" ".")
                echo ""
                checkov -d "$path" --framework kubernetes
                ;;
            3)
                local file
                file=$(_prompt "Dockerfile path" "./Dockerfile")
                echo ""
                checkov -f "$file" --framework dockerfile
                ;;
            4)
                local path
                path=$(_prompt "CloudFormation directory" ".")
                echo ""
                checkov -d "$path" --framework cloudformation
                ;;
            5)
                local path output
                path=$(_prompt "Target directory" ".")
                output=$(_prompt "Output file" "/tmp/checkov-report.json")
                echo ""
                checkov -d "$path" -o json > "$output"
                log_message "success" "Report saved: ${output}"
                ;;
            *) log_message "error" "Invalid choice"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

_prowler_check_aws() {
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        if ! command_exists aws || ! aws sts get-caller-identity &>/dev/null 2>&1; then
            log_message "warning" "AWS credentials not configured"
            echo -e "${BRIGHT_GREEN}│"
            echo -e "╞─> ${BRIGHT_MAGENTA}${BOLD}AWS AUTHENTICATION${RESET}"
            echo -e "${BRIGHT_GREEN}╰─╮"
            echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}1${RESET}  Environment variables (enter now)"
            echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}2${RESET}  AWS CLI profile (~/.aws/credentials)"
            echo -e "${BRIGHT_GREEN}  ╞─> ${RED}B${RESET}  Cancel"
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
                    profile=$(_prompt "AWS CLI profile" "default")
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
        log_message "warning" "Azure credentials not configured"
        echo -e "${BRIGHT_GREEN}│"
        echo -e "╞─> ${BRIGHT_MAGENTA}${BOLD}AZURE AUTHENTICATION${RESET}"
        echo -e "${BRIGHT_GREEN}╰─╮"
        echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}1${RESET}  Service Principal (environment variables)"
        echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}2${RESET}  Azure CLI (az login already done)"
        echo -e "${BRIGHT_GREEN}  ╞─> ${RED}B${RESET}  Cancel"
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
                log_message "info" "Using Azure CLI (az login)"
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
            log_message "warning" "GCP credentials not configured"
            echo -e "${BRIGHT_GREEN}│"
            echo -e "╞─> ${BRIGHT_MAGENTA}${BOLD}GCP AUTHENTICATION${RESET}"
            echo -e "${BRIGHT_GREEN}╰─╮"
            echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}1${RESET}  Service account key file (JSON)"
            echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}2${RESET}  gcloud CLI (gcloud auth already done)"
            echo -e "${BRIGHT_GREEN}  ╞─> ${RED}B${RESET}  Cancel"
            echo -e "${BRIGHT_GREEN}╭─╯"
            echo -e "${BRIGHT_GREEN}◉"
            echo ""
            read -rp "  > " _cred_choice
            case "${_cred_choice,,}" in
                1)
                    GOOGLE_APPLICATION_CREDENTIALS=$(_prompt "Path to JSON key file" "/path/to/key.json")
                    export GOOGLE_APPLICATION_CREDENTIALS
                    ;;
                2)
                    log_message "info" "Using gcloud CLI"
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
        log_message "error" "prowler is not installed — use the Install option"
        wait_enter; return
    fi
    while true; do
        _run_menu "PROWLER" \
            "AWS audit" \
            "Azure audit" \
            "GCP audit" \
            "List available checks" \
            "Targeted scan on an AWS service" \
            "Generate HTML report"
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
                output=$(_prompt "Output directory" "./output")
                case "$provider" in
                    aws)   _prowler_check_aws   || { wait_enter; continue; } ;;
                    azure) _prowler_check_azure || { wait_enter; continue; } ;;
                    gcp)   _prowler_check_gcp   || { wait_enter; continue; } ;;
                esac
                echo ""
                prowler "$provider" -M html -o "$output"
                log_message "success" "Report saved to: ${output}"
                ;;
            *) log_message "error" "Invalid choice"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_scoutsuite() {
    if ! command_exists scout; then
        log_message "error" "scoutsuite is not installed — use the Install option"
        wait_enter; return
    fi
    while true; do
        _run_menu "SCOUTSUITE" \
            "AWS audit" \
            "Azure audit (CLI auth)" \
            "GCP audit" \
            "Azure audit (Service Principal)" \
            "Open last report"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                _prowler_check_aws || { wait_enter; continue; }
                echo ""
                scout aws
                ;;
            2)
                log_message "info" "Make sure you have run: az login"
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
                    log_message "info" "Report: ${report}"
                    xdg-open "$report" 2>/dev/null || log_message "info" "Open manually: ${report}"
                else
                    log_message "warning" "No report found in the current directory"
                fi
                ;;
            *) log_message "error" "Invalid choice"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_teleport() {
    if ! command_exists teleport; then
        log_message "error" "teleport is not installed — use the Install option"
        wait_enter; return
    fi
    while true; do
        _run_menu "TELEPORT" \
            "Generate configuration" \
            "Start server" \
            "Show status" \
            "Create invite token" \
            "List connected nodes"
        [[ "${_run_choice,,}" == "b" ]] && return

        local dir
        dir=$(tool_dir teleport)
        echo ""
        case "$_run_choice" in
            1)
                local domain
                domain=$(_prompt "Public domain" "localhost")
                echo ""
                teleport configure -o "${dir}/teleport.yaml" \
                    --cluster-name="$domain" \
                    --public-addr="${domain}:3080" 2>/dev/null \
                    || teleport configure > "${dir}/teleport.yaml"
                log_message "success" "Config generated: ${dir}/teleport.yaml"
                ;;
            2)
                local config
                config=$(_prompt "Config file" "${dir}/teleport.yaml")
                if [[ ! -f "$config" ]]; then
                    log_message "error" "Configuration file not found: ${config}"
                    log_message "info" "Use option 1 to generate the configuration first"
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
                tctl nodes ls 2>/dev/null || log_message "warning" "Teleport server not accessible"
                ;;
            *) log_message "error" "Invalid choice"; sleep 1; continue ;;
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
        log_message "error" "Malcolm not installed — use the Install option from the menu"
        wait_enter
        return
    fi

    while true; do
        _run_menu "MALCOLM" \
            "Configure (install.py)" \
            "Start" \
            "Stop" \
            "Status" \
            "Logs"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                log_message "info" "Installing Malcolm Python dependencies..."
                # Malcolm requires ruamel.yaml and python-dotenv — install before install.py
                pip_install "ruamel.yaml" "python-dotenv" 2>/dev/null || true
                # apt fallback if pip_install was not enough
                if ! python3 -c "import ruamel.yaml" 2>/dev/null; then
                    log_message "info" "Trying via apt..."
                    apt-get install -y -qq python3-ruamel.yaml 2>/dev/null \
                        || log_message "warning" "ruamel.yaml not available via apt"
                fi
                if ! python3 -c "import dotenv" 2>/dev/null; then
                    apt-get install -y -qq python3-dotenv 2>/dev/null \
                        || log_message "warning" "python-dotenv not available via apt"
                fi
                log_message "info" "Launching Malcolm configuration..."
                python3 "${dir}/scripts/install.py"
                ;;
            2)
                log_message "step" "Starting Malcolm..."
                python3 "${dir}/scripts/start.py"
                ;;
            3)
                log_message "step" "Stopping Malcolm..."
                python3 "${dir}/scripts/stop.py" 2>/dev/null \
                    || (cd "$dir" && $COMPOSE_CMD down 2>/dev/null) \
                    || log_message "error" "Stop script not found"
                ;;
            4)
                python3 "${dir}/scripts/status.py" 2>/dev/null \
                    || (cd "$dir" && $COMPOSE_CMD ps 2>/dev/null) \
                    || log_message "warning" "Status script not found"
                ;;
            5)
                local svc
                svc=$(_prompt "Service (leave empty for all)" "")
                echo ""
                if [[ -n "$svc" ]]; then
                    compose_in_dir "$dir" logs --tail=100 "$svc" 2>/dev/null \
                        || log_message "error" "Service not found: ${svc}"
                else
                    compose_in_dir "$dir" logs --tail=50 2>/dev/null \
                        || log_message "error" "Compose not configured — run configuration first"
                fi
                ;;
            *) log_message "error" "Invalid choice"; sleep 1; continue ;;
        esac
        wait_enter
    done
}

run_nmap() {
    if ! command_exists nmap; then
        log_message "error" "nmap is not installed — use the Install option"
        wait_enter; return
    fi
    while true; do
        _run_menu "NMAP" \
            "Quick scan (top ports)" \
            "Full scan with scripts" \
            "Service detection scan" \
            "OT / Modbus scan" \
            "OT / BACnet scan" \
            "Stealth scan (SYN)" \
            "Generate XML report"
        [[ "${_run_choice,,}" == "b" ]] && return

        echo ""
        case "$_run_choice" in
            1)
                local target
                target=$(_prompt "Target (IP / range)" "192.168.1.0/24")
                echo ""
                nmap -F "$target"
                ;;
            2)
                _check_root || { wait_enter; continue; }
                local target
                target=$(_prompt "Target (IP / range)" "192.168.1.0/24")
                echo ""
                nmap -sV -sC -O "$target"
                ;;
            3)
                local target
                target=$(_prompt "Target (IP / range)" "192.168.1.0/24")
                echo ""
                nmap -sV --version-intensity 5 "$target"
                ;;
            4)
                local target nse_dir="/usr/share/nmap/scripts"
                if [[ ! -f "${nse_dir}/modbus-discover.nse" ]]; then
                    log_message "warning" "modbus-discover script missing — install nmap-scripts or a recent version of nmap"
                    wait_enter; continue
                fi
                target=$(_prompt "Target (IP)" "192.168.1.100")
                echo ""
                nmap -p 502 --script modbus-discover "$target"
                ;;
            5)
                local target nse_dir="/usr/share/nmap/scripts"
                if [[ ! -f "${nse_dir}/bacnet-info.nse" ]]; then
                    log_message "warning" "bacnet-info script missing — install nmap-scripts or a recent version of nmap"
                    wait_enter; continue
                fi
                target=$(_prompt "Target (IP)" "192.168.1.100")
                echo ""
                nmap -p 47808 --script bacnet-info "$target"
                ;;
            6)
                _check_root || { wait_enter; continue; }
                local target
                target=$(_prompt "Target (IP / range)" "192.168.1.0/24")
                echo ""
                nmap -sS "$target"
                ;;
            7)
                local target output
                target=$(_prompt "Target (IP / range)" "192.168.1.0/24")
                output=$(_prompt "Output file" "/tmp/nmap-scan.xml")
                echo ""
                nmap -sV -oX "$output" "$target"
                log_message "success" "Report saved: ${output}"
                ;;
            *) log_message "error" "Invalid choice"; sleep 1; continue ;;
        esac
        wait_enter
    done
}
