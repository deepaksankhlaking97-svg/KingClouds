#!/usr/bin/env bash

set -u

# ============================================================
#                 👑 KINGCLOUD INSTALLER HUB
# ============================================================

RESET='\033[0m'
BOLD='\033[1m'

PURPLE='\033[38;5;141m'
CYAN='\033[38;5;51m'
GREEN='\033[38;5;82m'
YELLOW='\033[38;5;220m'
RED='\033[38;5;203m'
WHITE='\033[38;5;255m'
GRAY='\033[38;5;245m'

LOG_DIR="/tmp/kingcloud"
mkdir -p "$LOG_DIR"

hide_cursor() {
    printf '\033[?25l'
}

show_cursor() {
    printf '\033[?25h'
}

clear_screen() {
    printf '\033[2J\033[H'
}

trap 'show_cursor' EXIT
trap 'show_cursor; exit 130' INT TERM

center() {
    local text="$1"
    local width
    local length
    local padding

    width=$(tput cols 2>/dev/null || echo 80)
    length=${#text}
    padding=$(( (width - length) / 2 ))

    [ "$padding" -lt 0 ] && padding=0

    printf '%*s%b\n' "$padding" '' "$text"
}

line() {
    printf '%b\n' \
        "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

spinner() {
    local text="$1"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i

    for i in $(seq 1 18); do
        printf '\r%b %b' \
            "${CYAN}${frames[$((i % 10))]}${RESET}" \
            "${WHITE}${text}${RESET}"
        sleep 0.08
    done

    printf '\r%b %b\n' \
        "${GREEN}✔${RESET}" \
        "${WHITE}${text}${RESET}"
}

progress() {
    local title="$1"
    local width=40
    local i
    local filled
    local empty

    for i in $(seq 0 2 100); do
        filled=$((i * width / 100))
        empty=$((width - filled))

        printf '\r%b [' "${CYAN}${title}${RESET}"

        [ "$filled" -gt 0 ] &&
            printf '%*s' "$filled" '' | tr ' ' '█'

        [ "$empty" -gt 0 ] &&
            printf '%*s' "$empty" '' | tr ' ' '░'

        printf '] %3d%%' "$i"

        sleep 0.015
    done

    printf '\n'
}

logo() {
    echo

    center "${PURPLE}${BOLD}██╗  ██╗██╗███╗   ██╗ ██████╗${RESET}"
    center "${PURPLE}${BOLD}██║ ██╔╝██║████╗  ██║██╔════╝${RESET}"
    center "${CYAN}${BOLD}█████╔╝ ██║██╔██╗ ██║██║  ███╗${RESET}"
    center "${CYAN}${BOLD}██╔═██╗ ██║██║╚██╗██║██║   ██║${RESET}"
    center "${PURPLE}${BOLD}██║  ██╗██║██║ ╚████║╚██████╔╝${RESET}"
    center "${PURPLE}${BOLD}╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝${RESET}"

    echo
    center "${WHITE}${BOLD}C L O U D   I N S T A L L E R${RESET}"
    center "${GRAY}Premium KINGCLOUD Terminal${RESET}"
    echo
}

# ============================================================
#              DIRECT HIDDEN COMMAND RUNNER
# ============================================================

run_vscode() {

    local logfile="$LOG_DIR/vscode.log"

    # Actual installer runs here AFTER 100%.
    # stdout/stderr are hidden in the log.
    bash <(
        curl -fsSL \
        "https://raw.githubusercontent.com/deepaksankhlaking97-svg/vs/refs/heads/main/vs.sh"
    ) >"$logfile" 2>&1

    return $?
}

run_container() {

    local logfile="$LOG_DIR/container.log"

    # Actual installer runs here AFTER 100%.
    # stdout/stderr are hidden in the log.
    bash <(
        curl -fsSL \
        "https://raw.githubusercontent.com/deepaksankhlaking97-svg/vs/refs/heads/main/container.sh"
    ) >"$logfile" 2>&1

    return $?
}

# ============================================================
#                     STARTUP
# ============================================================

startup() {

    clear_screen
    hide_cursor

    logo

    spinner "Initializing KINGCLOUD"
    spinner "Loading installer engine"
    spinner "Preparing cloud environment"

    echo

    center "${GREEN}${BOLD}✔ KINGCLOUD READY${RESET}"

    sleep 1
}

# ============================================================
#                    VS CODE
# ============================================================

install_vscode() {

    clear_screen
    hide_cursor

    logo

    center "${CYAN}${BOLD}VS CODE INSTALLER${RESET}"

    echo
    line
    echo

    spinner "Preparing VS Code"
    spinner "Connecting to installer"
    spinner "Starting installation"

    echo

    # Animation completes FIRST.
    progress "Installing VS Code"

    echo

    # NOW the real installer runs.
    spinner "Finalizing VS Code installation"

    run_vscode
    local result=$?

    echo

    if [ "$result" -eq 0 ]; then
        center "${GREEN}${BOLD}✔ VS CODE INSTALLATION COMPLETE${RESET}"
    else
        center "${RED}${BOLD}✖ VS CODE INSTALLATION FAILED${RESET}"
        center "${GRAY}Installer log: $LOG_DIR/vscode.log${RESET}"
    fi

    echo
    read -r -p "Press ENTER to continue..."
}

# ============================================================
#                   CONTAINER
# ============================================================

install_container() {

    clear_screen
    hide_cursor

    logo

    center "${CYAN}${BOLD}CONTAINER INSTALLER${RESET}"

    echo
    line
    echo

    spinner "Preparing container environment"
    spinner "Connecting to installer"
    spinner "Starting installation"

    echo

    # Animation completes FIRST.
    progress "Installing Container"

    echo

    # NOW the real installer runs.
    spinner "Finalizing Container installation"

    run_container
    local result=$?

    echo

    if [ "$result" -eq 0 ]; then
        center "${GREEN}${BOLD}✔ CONTAINER INSTALLATION COMPLETE${RESET}"
    else
        center "${RED}${BOLD}✖ CONTAINER INSTALLATION FAILED${RESET}"
        center "${GRAY}Installer log: $LOG_DIR/container.log${RESET}"
    fi

    echo
    read -r -p "Press ENTER to continue..."
}

# ============================================================
#                   COMING SOON
# ============================================================

coming_soon() {

    clear_screen
    logo

    center "${YELLOW}${BOLD}COMING SOON${RESET}"

    echo
    line
    echo

    spinner "Preparing future KINGCLOUD feature"

    echo

    center "${WHITE}${BOLD}NEW FEATURES ARE COMING${RESET}"
    center "${GRAY}More KINGCLOUD tools will be added soon.${RESET}"

    echo

    printf '  %b Server Manager\n' "${PURPLE}◆${RESET}"
    printf '  %b Cloud Tools\n' "${PURPLE}◆${RESET}"
    printf '  %b Developer Tools\n' "${PURPLE}◆${RESET}"
    printf '  %b Container Tools\n' "${PURPLE}◆${RESET}"

    echo

    read -r -p "Press ENTER to continue..."
}

# ============================================================
#                       ABOUT
# ============================================================

about() {

    clear_screen
    logo

    center "${CYAN}${BOLD}ABOUT KINGCLOUD${RESET}"

    echo
    line
    echo

    center "${WHITE}${BOLD}KINGCLOUD INSTALLER HUB${RESET}"
    center "${GRAY}Fast • Clean • Animated • Simple${RESET}"

    echo

    printf '  %b VS Code Installer\n' "${GREEN}✔${RESET}"
    printf '  %b Container Installer\n' "${GREEN}✔${RESET}"
    printf '  %b Hidden installer output\n' "${GREEN}✔${RESET}"
    printf '  %b Animated interface\n' "${GREEN}✔${RESET}"
    printf '  %b Coming Soon modules\n' "${GREEN}✔${RESET}"

    echo

    center "${PURPLE}${BOLD}KINGCLOUD${RESET}"
    center "${GRAY}Build • Deploy • Manage${RESET}"

    echo

    read -r -p "Press ENTER to continue..."
}

# ============================================================
#                        MENU
# ============================================================

menu() {

    while true; do

        clear_screen
        hide_cursor
        logo

        line
        echo

        printf '  %b  %b\n' \
            "${PURPLE}${BOLD}[1]${RESET}" \
            "${WHITE}VS Code Installer${RESET}"

        printf '       %b\n\n' \
            "${GRAY}Install VS Code${RESET}"

        printf '  %b  %b\n' \
            "${PURPLE}${BOLD}[2]${RESET}" \
            "${WHITE}Container Installer${RESET}"

        printf '       %b\n\n' \
            "${GRAY}Install container environment${RESET}"

        printf '  %b  %b\n' \
            "${YELLOW}${BOLD}[3]${RESET}" \
            "${WHITE}Coming Soon${RESET}"

        printf '       %b\n\n' \
            "${GRAY}Future KINGCLOUD tools${RESET}"

        printf '  %b  %b\n' \
            "${CYAN}${BOLD}[4]${RESET}" \
            "${WHITE}About KINGCLOUD${RESET}"

        printf '       %b\n\n' \
            "${GRAY}About this installer${RESET}"

        printf '  %b  %b\n' \
            "${RED}${BOLD}[0]${RESET}" \
            "${WHITE}Exit${RESET}"

        echo
        line
        echo

        read -r -p "KINGCLOUD ❯ " choice

        case "$choice" in

            1)
                install_vscode
                ;;

            2)
                install_container
                ;;

            3)
                coming_soon
                ;;

            4)
                about
                ;;

            0)
                clear_screen
                show_cursor
                echo
                center "${PURPLE}${BOLD}👑 KINGCLOUD${RESET}"
                center "${GRAY}Thank you for using KINGCLOUD.${RESET}"
                echo
                exit 0
                ;;

            *)
                center "${RED}✖ Invalid option${RESET}"
                sleep 1
                ;;

        esac
    done
}

# ============================================================
#                        START
# ============================================================

startup
menu
