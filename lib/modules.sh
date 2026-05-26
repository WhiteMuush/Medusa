# lib/modules.sh — Interactive menus, dashboard, session management
# Sourced by medusa.sh — do not execute directly
# shellcheck shell=bash
[[ -n "${_MODULES_SH_LOADED:-}" ]] && return 0
_MODULES_SH_LOADED=1

# ============================================================================
# MODULE HANDLERS (per-category menus)
# ============================================================================

module_category() {
    local category="$1"
    local cat_name="$2"

    while true; do
        clear_screen
        display_header

        echo -e "${BRIGHT_GREEN}│"
        echo -e "╞─> ${BRIGHT_MAGENTA}${BOLD}${cat_name}${RESET}"
        echo -e "${BRIGHT_GREEN}│"
        echo -e "${BRIGHT_GREEN}╰─╮"

        local tools=()
        local i=1
        for tool in $(echo "${!TOOL_DESC[@]}" | tr ' ' '\n' | sort); do
            if [[ "${TOOL_CAT[$tool]}" == "$category" ]]; then
                tools+=("$tool")
                local status status_icon
                status=$(get_tool_status "$tool")

                case "$status" in
                    running)       status_icon="${GREEN}running ${RESET}" ;;
                    stopped)       status_icon="${RED}stopped ${RESET}" ;;
                    cli_installed) status_icon="${GREEN}installed${RESET}" ;;
                    installed)     status_icon="${YELLOW}installed${RESET}" ;;
                    *)             status_icon="${DIM}---      ${RESET}" ;;
                esac

                printf "%b  ╞─> %b%2d%b  %-18s %b  %b%s%b\n" \
                    "$BRIGHT_GREEN" "$CYAN" "$i" "$RESET" "$tool" "$status_icon" "$DIM" "${TOOL_DESC[$tool]}" "$RESET"
                ((i++))
            fi
        done

        echo -e "${BRIGHT_GREEN}╭─╯"
        echo -e "${BRIGHT_GREEN}│"
        echo -e "${BRIGHT_GREEN}╞─────────────╮"
        echo -e "${BRIGHT_GREEN}│ ${RED}B${RESET}  Back   ${BRIGHT_GREEN}  │"
        echo -e "${BRIGHT_GREEN}╞─────────────╯"
        echo -e "${BRIGHT_GREEN}│"
        echo -e "${BRIGHT_GREEN}◉"
        echo ""

        read -rp "  > " choice

        if [[ "${choice,,}" == "b" || "${choice,,}" == "back" || "$choice" == "0" ]]; then
            return
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#tools[@]}" ]]; then
            module_tool_action "${tools[$((choice-1))]}"
        else
            log_message "error" "Invalid choice: $choice"
            sleep 1
        fi
    done
}

module_tool_action() {
    local tool="$1"

    while true; do
        clear_screen
        display_header

        local status
        status=$(get_tool_status "$tool")
        local desc="${TOOL_DESC[$tool]}"
        local type="${TOOL_TYPE[$tool]}"

        local status_display
        case "$status" in
            running)       status_display="${GREEN}RUNNING${RESET}" ;;
            stopped)       status_display="${RED}STOPPED${RESET}" ;;
            cli_installed) status_display="${GREEN}INSTALLED (CLI)${RESET}" ;;
            installed)     status_display="${YELLOW}INSTALLED${RESET}" ;;
            *)             status_display="${DIM}NOT INSTALLED${RESET}" ;;
        esac

        echo -e "${BRIGHT_GREEN}│"
        echo -e "╞─> ${BRIGHT_MAGENTA}${BOLD}${tool}${RESET}"
        echo -e "${BRIGHT_GREEN}│  ${DIM}${desc}${RESET}"
        echo -e "${BRIGHT_GREEN}│  ${DIM}Type: ${type}  |  Status: ${status_display}"
        echo -e "${BRIGHT_GREEN}│"

        if [[ "$status" != "not_installed" ]]; then
            echo -e "${BRIGHT_GREEN}╞─> ${BRIGHT_MAGENTA}${BOLD}ACTIONS${RESET}"
            echo -e "${BRIGHT_GREEN}╰─╮"
            if [[ "$type" == "cli" ]]; then
                echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}1${RESET}  Launch"
                echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}2${RESET}  Reinstall"
                echo -e "${BRIGHT_GREEN}  ╞─> ${RED}3${RESET}  Remove"
            else
                echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}1${RESET}  Start"
                echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}2${RESET}  Stop"
                echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}3${RESET}  Restart"
                echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}4${RESET}  Detailed status"
                echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}5${RESET}  Logs"
                echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}6${RESET}  Reinstall"
                echo -e "${BRIGHT_GREEN}  ╞─> ${RED}7${RESET}  Remove"
            fi
            echo -e "${BRIGHT_GREEN}╭─╯"
        else
            echo -e "${BRIGHT_GREEN}╞─> ${BRIGHT_MAGENTA}${BOLD}ACTIONS${RESET}"
            echo -e "${BRIGHT_GREEN}╰─╮"
            echo -e "${BRIGHT_GREEN}  ╞─> ${GREEN}1${RESET}  Install / Deploy"
            echo -e "${BRIGHT_GREEN}╭─╯"
        fi

        echo -e "${BRIGHT_GREEN}│"
        echo -e "${BRIGHT_GREEN}╞─────────────╮"
        echo -e "${BRIGHT_GREEN}│ ${RED}B${RESET}  Back   ${BRIGHT_GREEN}  │"
        echo -e "${BRIGHT_GREEN}╞─────────────╯"
        echo -e "${BRIGHT_GREEN}│"
        echo -e "${BRIGHT_GREEN}◉"
        echo ""

        read -rp "  > " choice

        if [[ "${choice,,}" == "b" || "${choice,,}" == "back" || "$choice" == "0" ]]; then
            return
        fi

        echo ""

        if [[ "$status" != "not_installed" ]]; then
            if [[ "$type" == "cli" ]]; then
                case "$choice" in
                    1) dispatch_run "$tool" ;;
                    2) dispatch_deploy "$tool" ;;
                    3) docker_remove "$tool" ;;
                    *) log_message "error" "Invalid choice"; sleep 1; continue ;;
                esac
            else
                case "$choice" in
                    1) docker_up "$tool" ;;
                    2) docker_down "$tool" ;;
                    3) docker_restart "$tool" ;;
                    4) docker_status "$tool" ;;
                    5) docker_logs "$tool" ;;
                    6) dispatch_deploy "$tool" ;;
                    7) docker_remove "$tool" ;;
                    *) log_message "error" "Invalid choice"; sleep 1; continue ;;
                esac
            fi
        else
            case "$choice" in
                1) dispatch_deploy "$tool" ;;
                *) log_message "error" "Invalid choice"; sleep 1; continue ;;
            esac
        fi

        wait_enter
    done
}

# ============================================================================
# MANAGEMENT MODULES
# ============================================================================

module_status_dashboard() {
    clear_screen
    display_header

    echo -e "${BRIGHT_GREEN}│"
    echo -e "╞─> ${BRIGHT_MAGENTA}${BOLD}STATUS DASHBOARD${RESET}"
    echo -e "${BRIGHT_GREEN}│"
    echo -e "${BRIGHT_GREEN}╰─╮"
    printf "%b  │  %b%-20s %-14s %-8s %s%b\n" "$BRIGHT_GREEN" "$BOLD" "TOOL" "CATEGORY" "TYPE" "STATUS" "$RESET"
    echo -e "${BRIGHT_GREEN}  │"

    for tool in $(echo "${!TOOL_DESC[@]}" | tr ' ' '\n' | sort); do
        local cat="${TOOL_CAT[$tool]}"
        local type="${TOOL_TYPE[$tool]}"
        local status status_display
        status=$(get_tool_status "$tool")

        case "$status" in
            running)       status_display="${GREEN}running${RESET}" ;;
            stopped)       status_display="${RED}stopped${RESET}" ;;
            cli_installed) status_display="${GREEN}installed${RESET}" ;;
            installed)     status_display="${YELLOW}installed${RESET}" ;;
            *)             status_display="${DIM}---${RESET}" ;;
        esac

        printf "%b  ╞─> %b%-20s %-14s %-8s %b\n" "$BRIGHT_GREEN" "$RESET" "$tool" "$cat" "$type" "$status_display"
    done

    echo -e "${BRIGHT_GREEN}╭─╯"
    echo -e "${BRIGHT_GREEN}│"
    echo -e "${BRIGHT_GREEN}◉"
    echo ""
    wait_enter
}

module_start_all() {
    clear_screen
    log_message "step" "Starting all installed tools..."
    echo ""

    if [[ -z "$COMPOSE_CMD" ]]; then
        log_message "error" "docker compose not available"
        wait_enter
        return
    fi

    for tool in $(echo "${!TOOL_DESC[@]}" | tr ' ' '\n' | sort); do
        if is_tool_installed "$tool"; then
            local dir compose_file=""
            dir=$(tool_dir "$tool")
            if [[ -f "${dir}/docker-compose.yml" ]]; then
                compose_file="${dir}/docker-compose.yml"
            else
                compose_file=$(find "$dir" -maxdepth 2 -name "docker-compose.yml" 2>/dev/null | head -1)
            fi
            if [[ -n "$compose_file" ]]; then
                local compose_dir
                compose_dir=$(dirname "$compose_file")
                log_message "info" "Starting ${tool}..."
                if compose_in_dir "$compose_dir" up -d 2>/dev/null; then
                    log_message "success" "${tool} started"
                else
                    log_message "warning" "Failed to start ${tool}"
                fi
            fi
        fi
    done

    echo ""
    log_message "success" "Operation complete"
    wait_enter
}

module_stop_all() {
    clear_screen
    log_message "step" "Stopping all tools..."
    echo ""

    if [[ -z "$COMPOSE_CMD" ]]; then
        log_message "error" "docker compose not available"
        wait_enter
        return
    fi

    # Stop via docker-compose for each registered tool
    # Looks for the compose file in the root folder AND sub-directories
    for tool in $(echo "${!TOOL_DESC[@]}" | tr ' ' '\n' | sort); do
        if is_tool_installed "$tool"; then
            local dir compose_file=""
            dir=$(tool_dir "$tool")
            if [[ -f "${dir}/docker-compose.yml" ]]; then
                compose_file="${dir}/docker-compose.yml"
            else
                compose_file=$(find "$dir" -maxdepth 2 -name "docker-compose.yml" 2>/dev/null | head -1)
            fi
            if [[ -n "$compose_file" ]]; then
                local compose_dir
                compose_dir=$(dirname "$compose_file")
                log_message "info" "Stopping ${tool}..."
                if compose_in_dir "$compose_dir" down 2>/dev/null; then
                    log_message "success" "${tool} stopped"
                fi
            fi
        fi
    done

    # Safety net: stop any Docker containers prefixed with "medusa-"
    # that slipped through (e.g. containers started manually)
    local leftover
    leftover=$(docker ps -q --filter "name=medusa-" 2>/dev/null)
    if [[ -n "$leftover" ]]; then
        log_message "info" "Stopping leftover medusa containers..."
        docker stop $leftover 2>/dev/null || true
    fi

    echo ""
    log_message "success" "All tools stopped"
    wait_enter
}

# ============================================================================
# CONFIGURATION PAGE
# ============================================================================

show_config() {
    clear_screen
    display_header

    echo -e "${BRIGHT_GREEN}│"
    echo -e "╞─> ${BRIGHT_MAGENTA}${BOLD}CONFIGURATION${RESET}"
    echo -e "${BRIGHT_GREEN}│"

    # --- General ---
    echo -e "${BRIGHT_GREEN}╞─> ${BRIGHT_MAGENTA}${BOLD}General${RESET}"
    echo -e "${BRIGHT_GREEN}╰─╮"
    echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}Version         ${RESET}${BLUE}${SCRIPT_VERSION}${RESET}"
    echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}User            ${RESET}${BLUE}$(whoami)${RESET}"
    echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}Working Dir     ${RESET}${BLUE}$(pwd)${RESET}"
    echo -e "${BRIGHT_GREEN}╭─╯"
    echo -e "${BRIGHT_GREEN}│"

    # --- Environment ---
    echo -e "${BRIGHT_GREEN}╞─> ${BRIGHT_MAGENTA}${BOLD}Environment${RESET}"
    echo -e "${BRIGHT_GREEN}╰─╮"
    echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}Name            ${RESET}${GREEN}${ENV_NAME}${RESET}"
    echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}Tools Directory ${RESET}${BLUE}${TOOLS_DIR:-(not set)}${RESET}"
    if [[ -d "$TOOLS_DIR" ]]; then
        local installed_count=0
        for tool in $(echo "${!TOOL_DESC[@]}" | tr ' ' '\n'); do
            is_tool_installed "$tool" && ((installed_count++))
        done
        echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}Deployed tools  ${RESET}${BLUE}${installed_count}/${#TOOL_DESC[@]}${RESET}"
        echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}Size            ${RESET}${BLUE}$(du -sh "$TOOLS_DIR" 2>/dev/null | cut -f1)${RESET}"
    fi
    echo -e "${BRIGHT_GREEN}╭─╯"
    echo -e "${BRIGHT_GREEN}│"

    # --- Docker ---
    echo -e "${BRIGHT_GREEN}╞─> ${BRIGHT_MAGENTA}${BOLD}Docker${RESET}"
    echo -e "${BRIGHT_GREEN}╰─╮"
    if command_exists docker; then
        local docker_ver
        docker_ver=$(docker --version 2>/dev/null | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1)
        echo -e "${BRIGHT_GREEN}  ╞─> ${GREEN}[+]${RESET} Docker ${docker_ver}"
        if docker info &>/dev/null; then
            echo -e "${BRIGHT_GREEN}  ╞─> ${GREEN}[+]${RESET} Daemon running"
        else
            echo -e "${BRIGHT_GREEN}  ╞─> ${RED}[-]${RESET} Daemon not running"
        fi
    else
        echo -e "${BRIGHT_GREEN}  ╞─> ${RED}[-]${RESET} Docker not installed"
    fi
    if [[ -n "$COMPOSE_CMD" ]]; then
        echo -e "${BRIGHT_GREEN}  ╞─> ${GREEN}[+]${RESET} Compose: $COMPOSE_CMD"
    else
        echo -e "${BRIGHT_GREEN}  ╞─> ${RED}[-]${RESET} Compose not found"
    fi
    echo -e "${BRIGHT_GREEN}╭─╯"
    echo -e "${BRIGHT_GREEN}│"

    # --- System tools ---
    echo -e "${BRIGHT_GREEN}╞─> ${BRIGHT_MAGENTA}${BOLD}System tools${RESET}"
    echo -e "${BRIGHT_GREEN}╰─╮"
    local sys_tools=("git" "curl" "python3" "pip3" "openssl" "nmap" "yara" "oscap")
    for tool in "${sys_tools[@]}"; do
        if command_exists "$tool"; then
            echo -e "${BRIGHT_GREEN}  ╞─> ${GREEN}[+]${RESET} $tool"
        else
            echo -e "${BRIGHT_GREEN}  ╞─> ${RED}[-]${RESET} $tool ${DIM}(not installed)${RESET}"
        fi
    done
    echo -e "${BRIGHT_GREEN}╭─╯"
    echo -e "${BRIGHT_GREEN}│"

    # --- System ---
    echo -e "${BRIGHT_GREEN}╞─> ${BRIGHT_MAGENTA}${BOLD}System${RESET}"
    echo -e "${BRIGHT_GREEN}╰─╮"
    echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}Hostname        ${RESET}${BLUE}$(hostname)${RESET}"
    echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}Kernel          ${RESET}${BLUE}$(uname -r)${RESET}"
    echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}Shell           ${RESET}${BLUE}${SHELL}${RESET}"
    local total_ram
    total_ram=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}')
    [[ -n "$total_ram" ]] && echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}RAM             ${RESET}${BLUE}${total_ram}G${RESET}"
    local free_space
    free_space=$(df -BG "${TOOLS_DIR}" 2>/dev/null | tail -1 | awk '{print $4}')
    [[ -n "$free_space" ]] && echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}Free space      ${RESET}${BLUE}${free_space}${RESET}"
    if [[ -d "$BASE_DIR" ]]; then
        local env_count
        env_count=$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}Environments    ${RESET}${BLUE}${env_count}${RESET}"
        echo -e "${BRIGHT_GREEN}  ╞─> ${DIM}Total size      ${RESET}${BLUE}$(du -sh "$BASE_DIR" 2>/dev/null | cut -f1)${RESET}"
    fi
    echo -e "${BRIGHT_GREEN}╭─╯"
    echo -e "${BRIGHT_GREEN}│"
    echo -e "${BRIGHT_GREEN}╞─────────────╮"
    echo -e "${BRIGHT_GREEN}│ ${RED}B${RESET}  Back   ${BRIGHT_GREEN}  │"
    echo -e "${BRIGHT_GREEN}╞─────────────╯"
    echo -e "${BRIGHT_GREEN}│"
    echo -e "${BRIGHT_GREEN}◉"
    echo ""

    read -rp "  > " _
    return
}

# ============================================================================
# INPUT HANDLER
# ============================================================================

handle_selection() {
    local choice="$1"

    case "${choice,,}" in
        1) module_category "soc"         "SOC / Detection & Response" ;;
        2) module_category "grc"         "GRC / Governance & Compliance" ;;
        3) module_category "integration" "Integration (IAM, Cloud, CI/CD)" ;;
        4) module_category "ot"          "OT / Industrial Security" ;;
        5) module_status_dashboard ;;
        6) module_start_all ;;
        7) module_stop_all ;;
        c|config) show_config ;;
        q|quit|exit)
            echo ""
            log_message "info" "Session ended."
            echo ""
            exit 0
            ;;
        "") return ;;
        *)
            log_message "error" "Invalid option: $choice"
            sleep 1
            ;;
    esac
}

# ============================================================================
# MAIN LOOP
# ============================================================================

main_loop() {
    while true; do
        clear_screen
        display_header
        display_main_menu
        echo ""

        read -rp "  > " choice
        echo ""

        handle_selection "$choice"
    done
}

# ============================================================================
# SESSION INITIALIZATION
# ============================================================================

initialize_environment() {
    clear_screen
    display_header
    if [[ -d "$BASE_DIR" ]]; then
        local existing_envs
        mapfile -t existing_envs < <(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2>/dev/null | sort -r)

        if [[ ${#existing_envs[@]} -gt 0 ]]; then
            echo "${BRIGHT_GREEN}│"
            echo -e "╞─>  ${BRIGHT_MAGENTA}${BOLD}EXISTING ENVIRONMENT(S)${RESET}"
            echo -e "${BRIGHT_GREEN}╰─╮"
            local i=1
            for env in "${existing_envs[@]}"; do
                local size tools_count
                size=$(du -sh "$BASE_DIR/$env" 2>/dev/null | cut -f1)
                tools_count=$(find "$BASE_DIR/$env" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
                echo -e "${BRIGHT_GREEN}  │  ${RESET} ${env} ${DIM}(${size}, ${tools_count} tools)${RESET}"
                ((i++))
            done
            echo -e "${BRIGHT_GREEN}╭─╯"
        fi
    fi

    echo -e "${BRIGHT_GREEN}╞─>  ${BRIGHT_MAGENTA}${BOLD}CREATE AN ENVIRONMENT${RESET}"
    echo -e "${BRIGHT_GREEN}╰─╮"
    echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}1${RESET}  New environment"
    echo -e "${BRIGHT_GREEN}  │"
    echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}2${RESET}  Continue an existing environment"
    echo -e "${BRIGHT_GREEN}  │"
    echo -e "${BRIGHT_GREEN}  ╞─> ${CYAN}3${RESET}  Auto-generate (env_YYYYMMDD_HHMMSS)"
    echo -e "${BRIGHT_GREEN}  │"
    echo -e "${BRIGHT_GREEN}  ◉"
    echo ""
    read -rp "${BRIGHT_GREEN}  > " env_mode
    env_mode=${env_mode:-1}

    case "$env_mode" in
        1)
            clear_screen
            display_header
            echo -e "${BRIGHT_GREEN}│"
            echo -e "╞─>   ${BRIGHT_MAGENTA}EXAMPLES:${DIM} lab_soc, formind_audit_2025, test_grc${RESET}"
            echo "${BRIGHT_GREEN}│"
            echo -e "${BRIGHT_GREEN}◉"
            echo ""
            while true; do
                read -rp "${BRIGHT_GREEN}  >  Environment name: ${RESET}" custom_name
                custom_name=$(echo "$custom_name" | tr ' ' '_' | sed 's/[^a-zA-Z0-9_-]//g')

                if [[ -z "$custom_name" ]]; then
                    echo ""
                    log_message "error" "Name cannot be empty"
                    echo ""
                    continue
                fi

                if [[ -d "$BASE_DIR/$custom_name" ]]; then
                    log_message "warning" "Environment '$custom_name' already exists"
                    read -rp "  ${YELLOW}[?]${RESET} Continue with this environment? (Y/n): " cont_exist
                    if [[ "${cont_exist,,}" != "n" ]]; then
                        ENV_NAME="$custom_name"
                        TOOLS_DIR="$BASE_DIR/$ENV_NAME"
                        log_message "success" "Environment loaded: $ENV_NAME"
                        break
                    fi
                    continue
                fi

                ENV_NAME="$custom_name"
                TOOLS_DIR="$BASE_DIR/$ENV_NAME"
                log_message "success" "New environment: $ENV_NAME"
                break
            done
            ;;

        2)
            echo ""
            if [[ ! -d "$BASE_DIR" ]]; then
                log_message "error" "No existing environment"
                sleep 2
                initialize_environment
                return
            fi

            local envs
            mapfile -t envs < <(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" 2>/dev/null | sort -r)

            if [[ ${#envs[@]} -eq 0 ]]; then
                log_message "error" "No existing environment"
                sleep 2
                initialize_environment
                return
            fi
            clear_screen
            display_header
            echo -e "${BRIGHT_GREEN}│"
            echo -e "╞─>  ${BRIGHT_MAGENTA}${BOLD}SELECT${RESET}"
            echo -e "${BRIGHT_GREEN}│"
            echo -e "${BRIGHT_GREEN}╰─╮"
            local i=1
            for env in "${envs[@]}"; do
                local size tools_count date_mod
                size=$(du -sh "$BASE_DIR/$env" 2>/dev/null | cut -f1)
                tools_count=$(find "$BASE_DIR/$env" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
                # stat -c: GNU/Linux; stat -f: BSD/macOS
                if stat --version &>/dev/null 2>&1; then
                    date_mod=$(stat -c %y "$BASE_DIR/$env" 2>/dev/null | cut -d' ' -f1)
                else
                    date_mod=$(stat -f %Sm -t "%Y-%m-%d" "$BASE_DIR/$env" 2>/dev/null)
                fi

                echo -e "  ╞─>  ${BRIGHT_MAGENTA} ${CYAN}${i}${RESET}  ${env}"
                echo -e "${BRIGHT_GREEN}  │  ${DIM}Size: ${size} | Tools: ${tools_count} | Modified: ${date_mod}${RESET}"
                echo -e "${BRIGHT_GREEN}  │"

                ((i++))
            done
            echo -e "${BRIGHT_GREEN}╭─╯"
            echo -e "${BRIGHT_GREEN}◉"
            echo ""
            read -rp "  > " env_num
            env_num=${env_num:-1}

            if [[ "$env_num" =~ ^[0-9]+$ ]] && [[ $env_num -ge 1 ]] && [[ $env_num -le ${#envs[@]} ]]; then
                ENV_NAME="${envs[$((env_num-1))]}"
                TOOLS_DIR="$BASE_DIR/$ENV_NAME"
                log_message "success" "Environment loaded: $ENV_NAME"
            else
                log_message "error" "Invalid selection"
                sleep 2
                initialize_environment
                return
            fi
            ;;

        3|*)
            ENV_NAME="env_$(date +%Y%m%d_%H%M%S)"
            TOOLS_DIR="$BASE_DIR/$ENV_NAME"
            log_message "success" "Auto-generated: $ENV_NAME"
            ;;
    esac

    mkdir -p "$TOOLS_DIR" || { log_message "error" "Cannot create directory: ${TOOLS_DIR}"; return 1; }
    echo ""
    sleep 1
}
