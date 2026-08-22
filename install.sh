#!/usr/bin/env bash

# ============================================================
#                  👑 KINGCLOUD HUB
#              Premium Installer Terminal
# ============================================================

set -u

# ---------------- COLORS ----------------

RESET='\033[0m'
BOLD='\033[1m'

PURPLE='\033[38;5;141m'
CYAN='\033[38;5;51m'
GREEN='\033[38;5;82m'
YELLOW='\033[38;5;220m'
RED='\033[38;5;203m'
WHITE='\033[38;5;255m'
GRAY='\033[38;5;245m'

# ---------------- CONFIG ----------------

LOG_DIR="/tmp/kingcloud"

mkdir -p "$LOG_DIR"

# ---------------- TERMINAL ----------------

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

# ---------------- CENTER ----------------

center() {
    local text="$1"
    local width
    local length
    local padding

    width=$(tput cols 2>/dev/null || echo 80)
    length=${#text}

    padding=$(( (width - length) / 2 ))

    if [ "$padding" -lt 0 ]; then
        padding=0
    fi

    printf '%*s%b\n' "$padding" '' "$text"
}

# ---------------- LINE ----------------

line() {
    printf '%b\n' \
        "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ---------------- LOGO ----------------

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

# ---------------- SPINNER ----------------

spinner() {
    local text="$1"

    local frames=(
        '⠋'
        '⠙'
        '⠹'
        '⠸'
        '⠼'
        '⠴'
        '⠦'
        '⠧'
        '⠇'
        '⠏'
    )

    local i

    for i in $(seq 1 20); do

        printf '\r%b %b' \
            "${CYAN}${frames[$((i % 10))]}${RESET}" \
            "${WHITE}${text}${RESET}"

        sleep 0.07
    done

    printf '\r%b %b\n' \
        "${GREEN}✔${RESET}" \
        "${WHITE}${text}${RESET}"
}

# ---------------- PROGRESS ----------------

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

        if [ "$filled" -gt 0 ]; then
            printf '%*s' "$filled" '' | tr ' ' '█'
        fi

        if [ "$empty" -gt 0 ]; then
            printf '%*s' "$empty" '' | tr ' ' '░'
        fi

        printf '] %3d%%' "$i"

        sleep 0.015
    done

    printf '\n'
}

# ---------------- HIDDEN INSTALLER ----------------

run_hidden() {

    local name="$1"
    local url="$2"

    local script_file="${LOG_DIR}/${name}.sh"
    local log_file="${LOG_DIR}/${name}.log"

    # Download silently.
    if ! curl -fsSL "$url" \
        -o "$script_file" \
        2>/dev/null
    then
        return 1
    fi

    # Run installer silently.
    bash "$script_file" \
        >"$log_file" \
        2>&1

    local result=$?

    rm -f "$script_file"

    return "$result"
}

# ---------------- STARTUP ----------------

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
#                    VS CODE INSTALLER
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

    # 100% animation FIRST
    progress "Installing VS Code"

    echo

    # Actual installer starts AFTER 100%
    spinner "Finalizing VS Code installation"

    if run_hidden \
        "vscode" \
        "https://raw.githubusercontent.com/deepaksankhlaking97-svg/vs/refs/heads/main/vs.sh"
    then

        echo

        center "${GREEN}${BOLD}✔ VS CODE READY${RESET}"

    else

        echo

        center "${RED}${BOLD}✖ VS CODE INSTALLATION FAILED${RESET}"
        center "${GRAY}Installer returned an error.${RESET}"

    fi

    echo

    read -r -p "Press ENTER to continue..."
}

# ============================================================
#                  CONTAINER INSTALLER
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

    # 100% animation FIRST
    progress "Installing Container"

    echo

    # Actual installer starts AFTER 100%
    spinner "Finalizing Container installation"

    if run_hidden \
        "container" \
        "https://raw.githubusercontent.com/deepaksankhlaking97-svg/vs/refs/heads/main/container.sh"
    then

        echo

        center "${GREEN}${BOLD}✔ CONTAINER READY${RESET}"

    else

        echo

        center "${RED}${BOLD}✖ CONTAINER INSTALLATION FAILED${RESET}"
        center "${GRAY}Installer returned an error.${RESET}"

    fi

    echo

    read -r -p "Press ENTER to continue..."
}

# ============================================================
#                      COMING SOON
# ============================================================

coming_soon() {

    clear_screen
    hide_cursor

    logo

    center "${YELLOW}${BOLD}COMING SOON${RESET}"

    echo
    line
    echo

    spinner "Preparing future KINGCLOUD feature"

    echo

    center "${WHITE}${BOLD}NEW FEATURES ARE COMING${RESET}"

    echo

    center "${GRAY}Future KINGCLOUD modules will appear here.${RESET}"

    echo

    printf '  %b Server Manager\n' "${PURPLE}◆${RESET}"
    printf '  %b Cloud Tools\n' "${PURPLE}◆${RESET}"
    printf '  %b Developer Tools\n' "${PURPLE}◆${RESET}"
    printf '  %b Container Tools\n' "${PURPLE}◆${RESET}"
    printf '  %b More KINGCLOUD utilities\n' "${PURPLE}◆${RESET}"

    echo

    read -r -p "Press ENTER to continue..."
}

# ============================================================
#                         ABOUT
# ============================================================

about() {

    clear_screen
    hide_cursor

    logo

    center "${CYAN}${BOLD}ABOUT KINGCLOUD${RESET}"

    echo
    line
    echo

    center "${WHITE}${BOLD}KINGCLOUD INSTALLER HUB${RESET}"

    echo

    center "${GRAY}Premium terminal installer interface${RESET}"
    center "${GRAY}Fast • Clean • Animated • Simple${RESET}"

    echo

    printf '  %b VS Code Installer\n' "${GREEN}✔${RESET}"
    printf '  %b Container Installer\n' "${GREEN}✔${RESET}"
    printf '  %b Hidden installer output\n' "${GREEN}✔${RESET}"
    printf '  %b Animated progress system\n' "${GREEN}✔${RESET}"
    printf '  %b Coming Soon modules\n' "${GREEN}✔${RESET}"

    echo

    center "${PURPLE}${BOLD}KINGCLOUD${RESET}"
    center "${GRAY}Build • Deploy • Manage${RESET}"

    echo

    read -r -p "Press ENTER to continue..."
}

# ============================================================
#                          MENU
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

        read -r -p "$(printf '%b' "${PURPLE}${BOLD}KINGCLOUD ❯ ${RESET}")" choice

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
                echo
                center "${RED}✖ Invalid option${RESET}"
                sleep 1
                ;;

        esac

    done
}

# ============================================================
#                         START
# ============================================================

startup
menu
