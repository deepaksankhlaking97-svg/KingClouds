#!/usr/bin/env bash

# ============================================================
#                 👑 KINGCLOUD INSTALLER HUB
#              Premium Bash GUI • Animated UI
# ============================================================

set -u

# ---------- COLORS ----------
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

PURPLE="\033[38;5;141m"
CYAN="\033[38;5;51m"
BLUE="\033[38;5;75m"
GREEN="\033[38;5;82m"
YELLOW="\033[38;5;220m"
RED="\033[38;5;203m"
WHITE="\033[38;5;255m"
GRAY="\033[38;5;245m"

# ---------- TERMINAL ----------
clear_screen() {
    printf "\033[2J\033[H"
}

hide_cursor() {
    printf "\033[?25l"
}

show_cursor() {
    printf "\033[?25h"
}

trap show_cursor EXIT
trap 'show_cursor; exit 0' INT TERM

# ---------- HELPERS ----------
line() {
    printf "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}

center() {
    local text="$1"
    local width
    width=$(tput cols 2>/dev/null || echo 80)
    local len=${#text}
    local pad=$(( (width - len) / 2 ))

    (( pad < 0 )) && pad=0
    printf "%*s%b\n" "$pad" "" "$text"
}

pause_screen() {
    echo
    printf "${GRAY}Press ENTER to return to KINGCLOUD menu...${RESET}"
    read -r
}

spinner() {
    local text="$1"
    local duration="${2:-2}"
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local end=$((SECONDS + duration))
    local i=0

    while [ "$SECONDS" -lt "$end" ]; do
        printf "\r${CYAN}${frames[$((i % ${#frames[@]}))]}${RESET} ${WHITE}${text}${RESET}"
        sleep 0.08
        ((i++))
    done

    printf "\r${GREEN}✔${RESET} ${WHITE}${text}${RESET}\n"
}

progress() {
    local title="$1"
    local width=42

    for i in $(seq 0 2 100); do
        local filled=$((i * width / 100))
        local empty=$((width - filled))

        printf "\r${CYAN}${title}${RESET} ["
        printf "${PURPLE}%${filled}s${RESET}" "" | tr ' ' '█'
        printf "${GRAY}%${empty}s${RESET}" "" | tr ' ' '░'
        printf "] ${WHITE}%3d%%${RESET}" "$i"

        sleep 0.015
    done

    echo
}

# ---------- LOGO ----------
logo() {
    echo
    center "${PURPLE}${BOLD}██╗  ██╗██╗███╗   ██╗ ██████╗ ${RESET}"
    center "${PURPLE}${BOLD}██║ ██╔╝██║████╗  ██║██╔════╝ ${RESET}"
    center "${CYAN}${BOLD}█████╔╝ ██║██╔██╗ ██║██║  ███╗${RESET}"
    center "${CYAN}${BOLD}██╔═██╗ ██║██║╚██╗██║██║   ██║${RESET}"
    center "${PURPLE}${BOLD}██║  ██╗██║██║ ╚████║╚██████╔╝${RESET}"
    center "${PURPLE}${BOLD}╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ${RESET}"
    echo
    center "${WHITE}${BOLD}C L O U D   I N S T A L L E R   H U B${RESET}"
    center "${GRAY}Premium Server Tools • Fast • Simple • Reliable${RESET}"
    echo
}

# ---------- STARTUP ----------
startup() {
    clear_screen
    hide_cursor

    logo

    echo
    center "${CYAN}Initializing KINGCLOUD environment...${RESET}"
    echo

    progress "Booting interface"
    spinner "Loading installer modules" 1
    spinner "Checking terminal environment" 1
    spinner "Preparing KINGCLOUD services" 1

    echo
    center "${GREEN}${BOLD}✔ KINGCLOUD READY${RESET}"

    sleep 1
}

# ---------- HEADER ----------
header() {
    clear_screen

    echo
    center "${PURPLE}${BOLD}👑 KINGCLOUD INSTALLER HUB${RESET}"
    center "${GRAY}────────────────────────────────────────────${RESET}"
    echo

    printf " ${CYAN}Server:${RESET} ${WHITE}KINGCLOUD${RESET}"
    printf "    ${CYAN}Mode:${RESET} ${GREEN}ONLINE${RESET}"
    printf "    ${CYAN}Version:${RESET} ${WHITE}1.0${RESET}\n"

    echo
    line
    echo
}

# ---------- VS CODE ----------
install_vscode() {
    clear_screen
    logo

    echo
    center "${CYAN}${BOLD}VS CODE INSTALLER${RESET}"
    echo
    line
    echo

    echo " ${WHITE}This will run the official KINGCLOUD VS Code installer:${RESET}"
    echo
    echo " ${GRAY}bash <(curl -s https://raw.githubusercontent.com/${RESET}"
    echo " ${GRAY}deepaksankhlaking97-svg/vs/refs/heads/main/vs.sh)${RESET}"
    echo

    read -rp "$(printf "${YELLOW}Continue installation? [Y/n]: ${RESET}")" answer
    answer=${answer:-Y}

    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo
        spinner "Starting VS Code installer" 2
        echo

        bash <(curl -s https://raw.githubusercontent.com/deepaksankhlaking97-svg/vs/refs/heads/main/vs.sh)

        echo
        printf "${GREEN}${BOLD}✔ VS Code installer finished.${RESET}\n"
    else
        printf "\n${YELLOW}Installation cancelled.${RESET}\n"
    fi

    pause_screen
}

# ---------- CONTAINER ----------
install_container() {
    clear_screen
    logo

    echo
    center "${CYAN}${BOLD}CONTAINER INSTALLER${RESET}"
    echo
    line
    echo

    echo " ${WHITE}This will run the KINGCLOUD Container installer:${RESET}"
    echo
    echo " ${GRAY}bash <(curl -s https://raw.githubusercontent.com/${RESET}"
    echo " ${GRAY}deepaksankhlaking97-svg/vs/refs/heads/main/container.sh)${RESET}"
    echo

    read -rp "$(printf "${YELLOW}Continue installation? [Y/n]: ${RESET}")" answer
    answer=${answer:-Y}

    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo
        spinner "Starting Container installer" 2
        echo

        bash <(curl -s https://raw.githubusercontent.com/deepaksankhlaking97-svg/vs/refs/heads/main/container.sh)

        echo
        printf "${GREEN}${BOLD}✔ Container installer finished.${RESET}\n"
    else
        printf "\n${YELLOW}Installation cancelled.${RESET}\n"
    fi

    pause_screen
}

# ---------- COMING SOON ----------
coming_soon() {
    clear_screen

    echo
    center "${PURPLE}${BOLD}👑 KINGCLOUD${RESET}"
    echo
    center "${YELLOW}${BOLD}COMING SOON${RESET}"
    echo

    progress "Preparing future feature"

    echo
    center "${WHITE}This KINGCLOUD feature is currently under development.${RESET}"
    center "${GRAY}New cloud tools will be added in future updates.${RESET}"
    echo

    echo
    printf " ${CYAN}Planned modules:${RESET}\n"
    echo " ${GRAY}• Server Manager${RESET}"
    echo " ${GRAY}• Cloud Tools${RESET}"
    echo " ${GRAY}• Developer Tools${RESET}"
    echo " ${GRAY}• Advanced Container Tools${RESET}"
    echo " ${GRAY}• More KINGCLOUD utilities${RESET}"

    pause_screen
}

# ---------- ABOUT ----------
about() {
    clear_screen

    echo
    center "${PURPLE}${BOLD}👑 ABOUT KINGCLOUD${RESET}"
    echo
    line
    echo

    center "${WHITE}${BOLD}KINGCLOUD INSTALLER HUB${RESET}"
    echo
    center "${GRAY}A premium terminal interface for KINGCLOUD tools.${RESET}"
    center "${GRAY}Fast installation • Clean interface • Animated UI${RESET}"
    echo

    echo " ${CYAN}Features:${RESET}"
    echo " ${GREEN}✔${RESET} Animated startup"
    echo " ${GREEN}✔${RESET} Premium terminal GUI"
    echo " ${GREEN}✔${RESET} VS Code installer"
    echo " ${GREEN}✔${RESET} Container installer"
    echo " ${GREEN}✔${RESET} Coming Soon modules"
    echo " ${GREEN}✔${RESET} Easy navigation"
    echo

    echo " ${PURPLE}${BOLD}KINGCLOUD${RESET} ${GRAY}— Build. Deploy. Manage.${RESET}"

    pause_screen
}

# ---------- MENU ----------
menu() {
    while true; do
        header

        printf " ${PURPLE}${BOLD}MAIN MENU${RESET}\n\n"

        printf " ${CYAN}${BOLD}[1]${RESET}  ${WHITE}VS Code Installer${RESET}\n"
        printf "      ${GRAY}Install VS Code using KINGCLOUD installer${RESET}\n\n"

        printf " ${CYAN}${BOLD}[2]${RESET}  ${WHITE}Container Installer${RESET}\n"
        printf "      ${GRAY}Install KINGCLOUD container environment${RESET}\n\n"

        printf " ${YELLOW}${BOLD}[3]${RESET}  ${WHITE}Coming Soon${RESET}\n"
        printf "      ${GRAY}Future KINGCLOUD tools${RESET}\n\n"

        printf " ${BLUE}${BOLD}[4]${RESET}  ${WHITE}About KINGCLOUD${RESET}\n"
        printf "      ${GRAY}Information about this installer${RESET}\n\n"

        printf " ${RED}${BOLD}[0]${RESET}  ${WHITE}Exit${RESET}\n\n"

        line
        echo

        read -rp "$(printf " ${PURPLE}${BOLD}KINGCLOUD ❯ ${RESET}")" choice

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
                center "${PURPLE}${BOLD}👑 Thank you for using KINGCLOUD!${RESET}"
                echo
                show_cursor
                exit 0
                ;;
            *)
                printf "\n ${RED}✖ Invalid option.${RESET}\n"
                sleep 1
                ;;
        esac
    done
}

# ---------- RUN ----------
startup
menu
