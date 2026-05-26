# lib/core.sh — Colors, global variables, utilities, Docker helpers, tool registry
# Sourced by medusa.sh — do not execute directly
# shellcheck shell=bash
[[ -n "${_CORE_SH_LOADED:-}" ]] && return 0
_CORE_SH_LOADED=1

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================
_def() {
    declare -p "$1" &>/dev/null && return
    local val="$2"
    # ANSI fallback if tput failed (empty val)
    if [[ -z "$val" ]]; then
        case "$1" in
            RESET)          val=$'\e[0m'  ;;
            BOLD)           val=$'\e[1m'  ;;
            DIM)            val=$'\e[2m'  ;;
            RED)            val=$'\e[31m' ;;
            GREEN)          val=$'\e[32m' ;;
            YELLOW)         val=$'\e[33m' ;;
            BLUE)           val=$'\e[34m' ;;
            MAGENTA)        val=$'\e[35m' ;;
            CYAN)           val=$'\e[36m' ;;
            BRIGHT_RED)     val=$'\e[91m' ;;
            BRIGHT_GREEN)   val=$'\e[92m' ;;
            BRIGHT_YELLOW)  val=$'\e[93m' ;;
            BRIGHT_BLUE)    val=$'\e[94m' ;;
            BRIGHT_MAGENTA) val=$'\e[95m' ;;
            BRIGHT_CYAN)    val=$'\e[96m' ;;
        esac
    fi
    readonly "$1"="$val"
}

_def RESET      "$(tput sgr0   2>/dev/null)"
_def BOLD       "$(tput bold   2>/dev/null)"
_def DIM        "$(tput dim    2>/dev/null)"

_def RED        "$(tput setaf 1  2>/dev/null)"
_def GREEN      "$(tput setaf 2  2>/dev/null)"
_def YELLOW     "$(tput setaf 3  2>/dev/null)"
_def BLUE       "$(tput setaf 4  2>/dev/null)"
_def MAGENTA    "$(tput setaf 5  2>/dev/null)"
_def CYAN       "$(tput setaf 6  2>/dev/null)"

_def BRIGHT_RED     "$(tput setaf 9  2>/dev/null)"
_def BRIGHT_GREEN   "$(tput setaf 10 2>/dev/null)"
_def BRIGHT_YELLOW  "$(tput setaf 11 2>/dev/null)"
_def BRIGHT_BLUE    "$(tput setaf 12 2>/dev/null)"
_def BRIGHT_MAGENTA "$(tput setaf 13 2>/dev/null)"
_def BRIGHT_CYAN    "$(tput setaf 14 2>/dev/null)"

unset -f _def

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================
declare -p SCRIPT_VERSION &>/dev/null || readonly SCRIPT_VERSION="${BRIGHT_GREEN}version 0.1.0"
declare -p SCRIPT_NAME    &>/dev/null || readonly SCRIPT_NAME="Medusa, the gaze that neutralizes your vulnerabilities."
# BASE_DIR must be absolute: after the first `cd` (docker compose, repo clone,
# etc.) all `tool_dir` calls would return wrong paths otherwise.
declare -p BASE_DIR       &>/dev/null || readonly BASE_DIR="${MEDUSA_HOME:-$PWD}/medusa_deployments"
declare -p UI_WIDTH       &>/dev/null || readonly UI_WIDTH=62
COMPOSE_CMD=""
ENV_NAME="" # shellcheck disable=SC2034
TOOLS_DIR=""

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# pip_install <package> [package2 ...]
# Installs via pipx if available, otherwise pip3 with Debian/Ubuntu 12+ flags
pip_install() {
    if command_exists pipx; then
        for pkg in "$@"; do
            pipx install "$pkg"
        done
    elif command_exists pip3; then
        pip3 install --break-system-packages --ignore-installed "$@"
    else
        log_message "error" "pip3 and pipx are both missing"
        return 1
    fi
}

clear_screen() {
    clear
    tput cup 0 0
}

ui_rule() {
    printf '  %s' "${CYAN}"
    printf '%*s' "$UI_WIDTH" '' | tr ' ' '-'
    printf '%s\n' "${RESET}"
}

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        info)    echo -e "  ${BLUE}[i]${RESET} ${timestamp} ${message}" ;;
        success) echo -e "  ${GREEN}[+]${RESET} ${timestamp} ${message}" ;;
        warning) echo -e "  ${YELLOW}[!]${RESET} ${timestamp} ${message}" ;;
        error)   echo -e "  ${RED}[-]${RESET} ${timestamp} ${message}" ;;
        step)    echo -e "  ${CYAN}[*]${RESET} ${timestamp} ${message}" ;;
        *)       echo -e "  ${DIM}[?]${RESET} ${timestamp} ${message}" ;;
    esac
}

command_exists() {
    command -v "$1" &>/dev/null
}

gen_password() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c "${1:-24}"
}

gen_uuid() {
    python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null \
        || cat /proc/sys/kernel/random/uuid 2>/dev/null \
        || openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/'
}

confirm() {
    local msg="${1:-Continue?}"
    read -rp "  ${YELLOW}[?]${RESET} ${msg} [y/N]: " reply
    [[ "$reply" =~ ^[oOyY]$ ]]
}

# prompt_value <label> [default]  → echoes the user input (or default if empty)
prompt_value() {
    local label="$1" default="${2:-}" value
    if [[ -n "$default" ]]; then
        read -rp "  ${CYAN}${label}${RESET} [${DIM}${default}${RESET}]: " value
    else
        read -rp "  ${CYAN}${label}${RESET}: " value
    fi
    echo "${value:-$default}"
}

# prompt_yesno <message> [default=N]  → returns 0 on yes, 1 on no
prompt_yesno() {
    local msg="${1:-Continue?}" default="${2:-N}" reply hint
    if [[ "${default^^}" == "Y" ]]; then
        hint="[Y/n]"
    else
        hint="[y/N]"
    fi
    read -rp "  ${YELLOW}[?]${RESET} ${msg} ${hint}: " reply
    reply="${reply:-$default}"
    [[ "$reply" =~ ^[oOyY]$ ]]
}

# run_in_dir <dir> <cmd...>  → runs cmd in a subshell so the parent shell
# never leaks a `cd` to the caller (preserves $PWD for the menu loop).
run_in_dir() {
    local dir="$1"; shift
    (cd "$dir" && "$@")
}

# compose_in_dir <dir> <compose-args...>  → run docker compose inside <dir>
compose_in_dir() {
    local dir="$1"; shift
    (cd "$dir" && $COMPOSE_CMD "$@")
}

# ensure_command_absent <cmd>  → returns 1 if cmd is already on PATH (and
# logs a warning + wait_enter), 0 otherwise. Use at the top of CLI installers
# to skip duplicate installation.
ensure_command_absent() {
    local cmd="$1" version=""
    if command_exists "$cmd"; then
        version=$("$cmd" --version 2>&1 | head -1)
        log_message "warning" "${cmd} already installed: ${version}"
        wait_enter
        return 1
    fi
    return 0
}

# mark_cli_installed <tool>  → create the marker file Medusa uses to know
# that a CLI tool has been deployed by us.
mark_cli_installed() {
    local tool="$1" dir
    dir=$(tool_dir "$tool")
    mkdir -p "$dir"
    touch "${dir}/.installed"
}

wait_enter() {
    echo ""
    read -rp "  ${DIM}Press Enter to continue...${RESET}"
}

detect_compose_cmd() {
    if command_exists docker && docker compose version &>/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif command_exists docker-compose; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD=""
    fi
}

# ============================================================================
# DISPLAY FUNCTIONS
# ============================================================================

display_header() {
    echo -e "${BRIGHT_MAGENTA}"
    cat <<'EOF'
   ██████   ██████              █████
  ▒▒██████ ██████              ▒▒███
   ▒███▒█████▒███   ██████   ███████  █████ ████  █████   ██████
   ▒███▒▒███ ▒███  ███▒▒███ ███▒▒███ ▒▒███ ▒███  ███▒▒   ▒▒▒▒▒███
   ▒███ ▒▒▒  ▒███ ▒███████ ▒███ ▒███  ▒███ ▒███ ▒▒█████   ███████
   ▒███      ▒███ ▒███▒▒▒  ▒███ ▒███  ▒███ ▒███  ▒▒▒▒███ ███▒▒███
   █████     █████▒▒██████ ▒▒████████ ▒▒████████ ██████ ▒▒████████
  ▒▒▒▒▒     ▒▒▒▒▒  ▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒ ▒▒▒▒▒▒   ▒▒▒▒▒▒▒▒

EOF
    echo -e "                                                    ${DIM}${SCRIPT_VERSION}${RESET}"
    echo -e "${BRIGHT_GREEN}╭────────────────────────────────────────────────────────────────╮"
    echo "│                                                                │"
    echo -e "│          ${SCRIPT_NAME}         │"
    echo "│                                                                │"
    echo "╞────────────────────────────────────────────────────────────────╯"
}

display_main_menu() {
    echo "${BRIGHT_GREEN}│"
    echo -e "╞─> ${BRIGHT_MAGENTA}${BOLD}MODULES${RESET}"
    echo -e "${BRIGHT_GREEN}│"
    echo -e "${BRIGHT_GREEN}╰─╮"
    echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}1${RESET}  SOC / Detection & Response           ${DIM}14 tools${RESET}"
    echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}2${RESET}  GRC / Governance & Compliance         ${DIM}5 tools${RESET}"
    echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}3${RESET}  Integration (IAM, Cloud, CI/CD)      ${DIM}11 tools${RESET}"
    echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}4${RESET}  OT / Industrial Security              ${DIM}5 tools${RESET}"
    echo -e "${BRIGHT_GREEN}╭─╯"
    echo -e "${BRIGHT_GREEN}╞─> ${BRIGHT_MAGENTA}${BOLD}MANAGEMENT${RESET}"
    echo -e "${BRIGHT_GREEN}╰─╮"
    echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}5${RESET}  Status Dashboard"
    echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}6${RESET}  Start All Deployed Tools"
    echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}7${RESET}  Stop All Tools"
    echo -e "${BRIGHT_GREEN}╭─╯"
    echo -e "${BRIGHT_GREEN}│"
    echo -e "${BRIGHT_GREEN}╞─────────────────────────────╮"
    echo -e "${BRIGHT_GREEN}│ ${CYAN}C${RESET}  Configuration    ${RED}Q${RESET}  Quit${BRIGHT_GREEN} │"
    echo -e "${BRIGHT_GREEN}╞─────────────────────────────╯"
    echo -e "${BRIGHT_GREEN}│"
    echo -e "${BRIGHT_GREEN}◉"
}

show_access_info() {
    local tool="$1"
    shift
    echo ""
    ui_rule
    echo -e "  ${BOLD}${tool}${RESET}"
    ui_rule
    for line in "$@"; do
        echo -e "    ${line}"
    done
    ui_rule
}

# ============================================================================
# PREREQUISITES
# ============================================================================

check_dependencies() {
    local missing=()

    if ! command_exists docker; then
        missing+=("docker")
    fi

    if ! command_exists git; then
        missing+=("git")
    fi

    detect_compose_cmd
    if [[ -z "$COMPOSE_CMD" ]]; then
        missing+=("docker-compose")
    fi

    local recommended=("curl" "python3" "pip3" "openssl")
    local missing_rec=()
    for tool in "${recommended[@]}"; do
        if ! command_exists "$tool"; then
            missing_rec+=("$tool")
        fi
    done

    if [[ ${#missing[@]} -gt 0 || ${#missing_rec[@]} -gt 0 ]]; then
        clear_screen
        if [[ ${#missing[@]} -gt 0 ]]; then
            log_message "error" "Missing critical prerequisites:"
            for tool in "${missing[@]}"; do
                echo -e "    ${RED}[-]${RESET} $tool"
            done
            echo ""
        fi
        if [[ ${#missing_rec[@]} -gt 0 ]]; then
            log_message "warning" "Missing recommended tools:"
            for tool in "${missing_rec[@]}"; do
                echo -e "    ${YELLOW}[!]${RESET} $tool"
            done
            echo ""
        fi
        echo "  ${DIM}Medusa will run with reduced capabilities.${RESET}"
        echo ""
        read -rp "  ${DIM}Press Enter to continue...${RESET}"
    fi
}

# ============================================================================
# DOCKER MANAGEMENT (generic)
# ============================================================================

tool_dir() {
    echo "${TOOLS_DIR}/${1}"
}

is_tool_installed() {
    local tool="$1"
    local dir
    dir=$(tool_dir "$tool")

    # Medusa marker (docker-compose.yml or .installed)
    if [[ -d "$dir" ]] && { [[ -f "${dir}/docker-compose.yml" ]] || [[ -f "${dir}/.installed" ]]; }; then
        return 0
    fi

    # CLI tool already present on the system (installed outside Medusa)
    if [[ "${TOOL_TYPE[$tool]:-}" == "cli" ]]; then
        local bin="${tool//-/_}"
        # Special cases: binary name differs from tool name
        case "$tool" in
            sigma)      bin="sigma" ;;
            openscap)   bin="oscap" ;;
            scoutsuite) bin="scout" ;;
            gitleaks)   bin="gitleaks" ;;
            teleport)   bin="teleport" ;;
            *) bin="$tool" ;;
        esac
        if command_exists "$bin"; then
            # Create the marker so Medusa remembers it
            mkdir -p "$dir"
            touch "${dir}/.installed"
            return 0
        fi
    fi

    return 1
}

get_tool_status() {
    local tool="$1"
    local dir
    dir=$(tool_dir "$tool")

    if ! is_tool_installed "$tool"; then
        echo "not_installed"
        return
    fi

    if [[ -f "${dir}/.installed" ]] && [[ ! -f "${dir}/docker-compose.yml" ]]; then
        echo "cli_installed"
        return
    fi

    local compose_file=""
    if [[ -f "${dir}/docker-compose.yml" ]]; then
        compose_file="${dir}/docker-compose.yml"
    elif [[ -n "$COMPOSE_CMD" ]]; then
        compose_file=$(find "$dir" -maxdepth 2 -name "docker-compose.yml" 2>/dev/null | head -1)
    fi

    if [[ -n "$compose_file" ]] && [[ -n "$COMPOSE_CMD" ]]; then
        local compose_dir running
        compose_dir=$(dirname "$compose_file")
        running=$(cd "$compose_dir" && $COMPOSE_CMD ps 2>/dev/null | grep -cE "Up|running" || true)
        if [[ ! "$running" =~ ^[0-9]+$ ]]; then running=0; fi
        if [[ "$running" -gt 0 ]]; then
            echo "running"
        else
            echo "stopped"
        fi
    else
        echo "installed"
    fi
}

_require_compose() {
    if [[ -z "$COMPOSE_CMD" ]]; then
        log_message "error" "docker compose not available — install Docker Desktop or docker-compose"
        return 1
    fi
    return 0
}

docker_up() {
    local tool="$1"
    local dir
    dir=$(tool_dir "$tool")
    _require_compose || return 1
    if [[ ! -f "${dir}/docker-compose.yml" ]]; then
        log_message "error" "Compose file not found for $tool"
        return 1
    fi
    log_message "step" "Starting ${tool}..."
    compose_in_dir "$dir" up -d
    log_message "success" "${tool} started"
}

docker_down() {
    local tool="$1"
    local dir
    dir=$(tool_dir "$tool")
    _require_compose || return 1
    if [[ ! -f "${dir}/docker-compose.yml" ]]; then
        log_message "error" "Compose file not found for $tool"
        return 1
    fi
    log_message "step" "Stopping ${tool}..."
    compose_in_dir "$dir" down
    log_message "success" "${tool} stopped"
}

docker_status() {
    local tool="$1"
    local dir
    dir=$(tool_dir "$tool")
    _require_compose || return 1
    if [[ ! -f "${dir}/docker-compose.yml" ]]; then
        log_message "warning" "Not a Docker tool"
        return 1
    fi
    compose_in_dir "$dir" ps
}

docker_logs() {
    local tool="$1"
    local lines="${2:-100}"
    local dir
    dir=$(tool_dir "$tool")
    _require_compose || return 1
    if [[ ! -f "${dir}/docker-compose.yml" ]]; then
        log_message "error" "Compose file not found for $tool"
        return 1
    fi
    compose_in_dir "$dir" logs --tail="$lines" -f
}

docker_restart() {
    local tool="$1"
    local dir
    dir=$(tool_dir "$tool")
    _require_compose || return 1
    if [[ ! -f "${dir}/docker-compose.yml" ]]; then
        log_message "error" "Compose file not found for $tool"
        return 1
    fi
    log_message "step" "Restarting ${tool}..."
    compose_in_dir "$dir" restart
    log_message "success" "${tool} restarted"
}

docker_remove() {
    local tool="$1"
    local dir
    dir=$(tool_dir "$tool")
    if [[ ! -d "$dir" ]]; then
        log_message "warning" "${tool} is not installed"
        return 0
    fi
    if confirm "Remove ${tool} and all its data?"; then
        if [[ -f "${dir}/docker-compose.yml" ]] && _require_compose; then
            compose_in_dir "$dir" down -v --remove-orphans 2>/dev/null || true
        fi
        rm -rf "$dir"
        log_message "success" "${tool} removed"
    fi
}

save_credentials() {
    local tool="$1"
    shift
    local creds_file
    creds_file="$(tool_dir "$tool")/credentials.txt"
    mkdir -p "$(tool_dir "$tool")"
    {
        echo "=============================="
        echo " ${tool} - Credentials"
        echo " Generated: $(date)"
        echo "=============================="
        for line in "$@"; do
            echo "$line"
        done
    } > "$creds_file"
    chmod 600 "$creds_file"
    log_message "info" "Credentials saved to ${creds_file}"
}

# ============================================================================
# TOOL REGISTRY
# ============================================================================

# shellcheck disable=SC2034
declare -A TOOL_DESC TOOL_CAT TOOL_TYPE

register_tool() {
    local name="$1" cat="$2" type="$3" desc="$4"
    TOOL_DESC["$name"]="$desc"
    TOOL_CAT["$name"]="$cat"
    TOOL_TYPE["$name"]="$type"
}

# --- SOC ---
register_tool "wazuh"          "soc" "docker" "SIEM/XDR - Detection, response, compliance"
register_tool "security-onion" "soc" "vm"     "NDR - Network monitoring (Suricata+Zeek)"
register_tool "suricata"       "soc" "docker" "High-performance network IDS/IPS"
register_tool "zeek"           "soc" "docker" "Passive network traffic analysis"
register_tool "opencti"        "soc" "docker" "CTI platform (threat intelligence)"
register_tool "misp"           "soc" "docker" "Indicators of compromise sharing"
register_tool "dfir-iris"      "soc" "docker" "Case management / forensic investigation"
register_tool "cortex"         "soc" "docker" "Observable enrichment & response"
register_tool "velociraptor"   "soc" "docker" "Endpoint forensics & threat hunting"
register_tool "shuffle"        "soc" "docker" "SOAR - Orchestration & automation"
register_tool "yara"           "soc" "cli"    "Malware detection rules"
register_tool "grr"            "soc" "docker" "Remote incident response (Google)"
register_tool "arkime"         "soc" "docker" "Network packet capture & indexing"
register_tool "sigma"          "soc" "cli"    "Generic detection rules"

# --- GRC ---
register_tool "eramba"         "grc" "docker" "GRC - Policies, risks, compliance"
register_tool "ciso-assistant" "grc" "docker" "Lightweight GRC - Multi-framework compliance"
register_tool "simplerisk"     "grc" "docker" "Risk management (registers, scoring)"
register_tool "openscap"       "grc" "cli"    "Compliance evaluation & hardening"
register_tool "gophish"        "grc" "docker" "Phishing simulation & awareness"

# --- Integration ---
register_tool "keycloak"       "integration" "docker" "IAM - SSO, MFA, identity federation"
register_tool "teleport"       "integration" "cli"    "PAM - Privileged access SSH/K8s/DB"
register_tool "vault"          "integration" "docker" "Secrets manager"
register_tool "trivy"          "integration" "cli"    "Container/IaC vulnerability scanner"
register_tool "semgrep"        "integration" "cli"    "SAST - Static code analysis"
register_tool "owasp-zap"      "integration" "docker" "DAST - Web security scanner"
register_tool "gitleaks"       "integration" "cli"    "Secret detection in Git repos"
register_tool "checkov"        "integration" "cli"    "Static IaC analysis (Terraform, K8s)"
register_tool "prowler"        "integration" "cli"    "Cloud security audit (AWS/Azure/GCP)"
register_tool "scoutsuite"     "integration" "cli"    "Multi-cloud audit"
register_tool "falco"          "integration" "docker" "Cloud-native runtime threat detection"

# --- OT ---
register_tool "malcolm"        "ot" "cli"    "OT network traffic analysis (CISA)"
register_tool "grfics"         "ot" "vm"     "SCADA/ICS simulation (training lab)"
register_tool "nmap"           "ot" "cli"    "Network mapping & NSE scripts"
register_tool "openvas"        "ot" "docker" "Network vulnerability scanner"
register_tool "grassmarlin"    "ot" "vm"     "Passive ICS network mapping (NSA)"

# ============================================================================
# DISPATCH DEPLOY
# ============================================================================

dispatch_deploy() {
    local tool="$1"
    local func="deploy_${tool//-/_}"

    if declare -f "$func" &>/dev/null; then
        $func
    else
        log_message "error" "No deployment function found for ${tool}"
    fi
}
