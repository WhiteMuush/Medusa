#!/usr/bin/env bash
# medusa.sh — Point d'entrée principal. Toute la logique est dans lib/
# -e volontairement absent : trop agressif pour un menu interactif (un read
# qui retourne 1, un grep sans match... tuent la boucle principale).
set -uo pipefail

# Résoudre le répertoire du script (même si lancé depuis un autre dossier).
# MEDUSA_HOME est ancré ici pour que les fonctions internes utilisent des
# chemins absolus, même après un `cd` ailleurs dans le script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export MEDUSA_HOME="${SCRIPT_DIR}"

# ============================================================================
# CHARGEMENT DES MODULES (ordre obligatoire)
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
# CLI — usage & list (helpers propres au point d'entrée)
# ============================================================================

usage() {
    cat << 'USAGE'
Usage: medusa [commande] [options]

Commandes:
  menu                      Menu interactif (defaut)
  deploy <outil>            Deployer un outil
  start <outil|all>         Demarrer un outil ou tous
  stop <outil|all>          Arreter un outil ou tous
  restart <outil>           Redemarrer un outil
  status [outil]            Afficher le status
  logs <outil> [lignes]     Afficher les logs
  remove <outil>            Supprimer un outil
  list [categorie]          Lister les outils (soc, grc, integration, ot)
  check                     Verifier les prerequis
  help                      Cette aide

Exemples:
  medusa deploy wazuh
  medusa start opencti
  medusa status
  medusa list soc
USAGE
}

cli_list_tools() {
    local filter="${1:-all}"
    echo ""
    printf "%b  %-20s %-14s %-8s %s%b\n" "$BOLD" "NOM" "CATEGORIE" "TYPE" "DESCRIPTION" "$RESET"
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
            local tool="${1:?Usage: medusa deploy <outil>}"
            ENV_NAME="${ENV_NAME:-default}"
            TOOLS_DIR="${BASE_DIR}/${ENV_NAME}"
            mkdir -p "$TOOLS_DIR"
            if [[ -z "${TOOL_DESC[$tool]+_}" ]]; then
                log_message "error" "Outil inconnu: ${tool}"
                exit 1
            fi
            dispatch_deploy "$tool"
            ;;

        start)
            local target="${1:?Usage: medusa start <outil|all>}"
            ENV_NAME="${ENV_NAME:-default}"
            TOOLS_DIR="${BASE_DIR}/${ENV_NAME}"
            if [[ "$target" == "all" ]]; then
                module_start_all
            else
                docker_up "$target"
            fi
            ;;

        stop)
            local target="${1:?Usage: medusa stop <outil|all>}"
            ENV_NAME="${ENV_NAME:-default}"
            TOOLS_DIR="${BASE_DIR}/${ENV_NAME}"
            if [[ "$target" == "all" ]]; then
                module_stop_all
            else
                docker_down "$target"
            fi
            ;;

        restart)
            local tool="${1:?Usage: medusa restart <outil>}"
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
            local tool="${1:?Usage: medusa logs <outil>}"
            local lines="${2:-100}"
            docker_logs "$tool" "$lines"
            ;;

        remove|uninstall)
            ENV_NAME="${ENV_NAME:-default}"
            TOOLS_DIR="${BASE_DIR}/${ENV_NAME}"
            local tool="${1:?Usage: medusa remove <outil>}"
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
            log_message "error" "Commande inconnue: ${cmd}"
            usage
            exit 1
            ;;
    esac
}

main "$@"
