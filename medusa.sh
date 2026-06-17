#!/usr/bin/env bash
# medusa.sh — Main entry point. All logic lives in lib/
# -e deliberately omitted: too aggressive for an interactive menu (a failing
# read, a grep with no match... would kill the main loop).
set -uo pipefail

# Resolve the script directory (even when launched from a different folder).
# MEDUSA_HOME is anchored here so internal functions use absolute paths,
# even after a `cd` elsewhere in the script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export MEDUSA_HOME="${SCRIPT_DIR}"

# Original argv, preserved so a sudo re-exec (_check_root) resumes the same
# command instead of dropping back to the default menu.
MEDUSA_ARGV=("$@")

# ============================================================================
# MODULE LOADING (order is mandatory)
# ============================================================================
# shellcheck source=lib/core.sh
source "${SCRIPT_DIR}/lib/core.sh"
# shellcheck source=lib/deploy_soc.sh
source "${SCRIPT_DIR}/lib/deploy_soc.sh"
# shellcheck source=lib/deploy_grc.sh
source "${SCRIPT_DIR}/lib/deploy_grc.sh"
# shellcheck source=lib/deploy_integration.sh
source "${SCRIPT_DIR}/lib/deploy_integration.sh"
# shellcheck source=lib/deploy_ot.sh
source "${SCRIPT_DIR}/lib/deploy_ot.sh"
# shellcheck source=lib/run_cli.sh
source "${SCRIPT_DIR}/lib/run_cli.sh"
# shellcheck source=lib/modules.sh
source "${SCRIPT_DIR}/lib/modules.sh"

# ============================================================================
# CLI — usage & list (helpers local to the entry point)
# ============================================================================

usage() {
    cat << 'USAGE'
Usage: medusa [command] [options]

Commands:
  menu                      Interactive menu (default)
  deploy <tool>             Deploy a tool
  start <tool|all>          Start a tool or all tools
  stop <tool|all>           Stop a tool or all tools
  restart <tool>            Restart a tool
  status [tool]             Show status
  logs <tool> [lines]       Show logs
  remove <tool>             Remove a tool
  list [category]           List tools (soc, grc, integration, ot)
  check                     Check prerequisites
  help                      This help

Examples:
  medusa deploy wazuh
  medusa start opencti
  medusa status
  medusa list soc
USAGE
}

cli_list_tools() {
    local filter="${1:-all}"
    echo ""
    printf "%b  %-20s %-14s %-8s %s%b\n" "$BOLD" "NAME" "CATEGORY" "TYPE" "DESCRIPTION" "$RESET"
    ui_rule
    for tool in $(echo "${!TOOL_DESC[@]}" | tr ' ' '\n' | sort); do
        if [[ "$filter" == "all" || "${TOOL_CAT[$tool]}" == "$filter" ]]; then
            printf "  %-20s %-14s %-8s %s\n" "$tool" "${TOOL_CAT[$tool]}" "${TOOL_TYPE[$tool]}" "${TOOL_DESC[$tool]}"
        fi
    done
    echo ""
}

# ============================================================================
# ENTRY POINT
# ============================================================================

main() {
    detect_compose_cmd 2>/dev/null || true

    local cmd="${1:-menu}"
    shift 2>/dev/null || true

    case "$cmd" in
        menu|"")
            if [[ $EUID -eq 0 ]]; then
                clear
                log_message "warning" "Running as root - proceed with caution!"
                sleep 2
            fi

            check_dependencies
            initialize_environment
            main_loop
            ;;

        deploy|install)
            local tool="${1:?Usage: medusa deploy <tool>}"
            ENV_NAME="${ENV_NAME:-default}"
            TOOLS_DIR="${BASE_DIR}/${ENV_NAME}"
            mkdir -p "$TOOLS_DIR"
            if [[ -z "${TOOL_DESC[$tool]+_}" ]]; then
                log_message "error" "Unknown tool: ${tool}"
                exit 1
            fi
            dispatch_deploy "$tool"
            ;;

        start)
            local target="${1:?Usage: medusa start <tool|all>}"
            ENV_NAME="${ENV_NAME:-default}"
            TOOLS_DIR="${BASE_DIR}/${ENV_NAME}"
            if [[ "$target" == "all" ]]; then
                module_start_all
            else
                docker_up "$target"
            fi
            ;;

        stop)
            local target="${1:?Usage: medusa stop <tool|all>}"
            ENV_NAME="${ENV_NAME:-default}"
            TOOLS_DIR="${BASE_DIR}/${ENV_NAME}"
            if [[ "$target" == "all" ]]; then
                module_stop_all
            else
                docker_down "$target"
            fi
            ;;

        restart)
            local tool="${1:?Usage: medusa restart <tool>}"
            ENV_NAME="${ENV_NAME:-default}"
            TOOLS_DIR="${BASE_DIR}/${ENV_NAME}"
            docker_restart "$tool"
            ;;

        status)
            ENV_NAME="${ENV_NAME:-default}"
            TOOLS_DIR="${BASE_DIR}/${ENV_NAME}"
            local tool="${1:-}"
            if [[ -n "$tool" ]]; then
                docker_status "$tool"
            else
                module_status_dashboard
            fi
            ;;

        logs)
            ENV_NAME="${ENV_NAME:-default}"
            TOOLS_DIR="${BASE_DIR}/${ENV_NAME}"
            local tool="${1:?Usage: medusa logs <tool>}"
            local lines="${2:-100}"
            docker_logs "$tool" "$lines"
            ;;

        remove|uninstall)
            ENV_NAME="${ENV_NAME:-default}"
            TOOLS_DIR="${BASE_DIR}/${ENV_NAME}"
            local tool="${1:?Usage: medusa remove <tool>}"
            docker_remove "$tool"
            ;;

        list|ls)
            cli_list_tools "${1:-all}"
            ;;

        check)
            check_dependencies
            ;;

        help|-h|--help)
            echo ""
            echo -e "  ${BOLD}Medusa${RESET} v${SCRIPT_VERSION} - Cybersecurity Toolkit"
            echo ""
            usage
            ;;

        version|-v|--version)
            echo "Medusa v${SCRIPT_VERSION}"
            ;;

        *)
            log_message "error" "Unknown command: ${cmd}"
            usage
            exit 1
            ;;
    esac
}

main "$@"
