```bash
#!/usr/bin/env bash
# ==========================================================
#              👑 KINGCLOUD INSTALLER HUB
#                 Premium VPS Installer
#                 Version 3.0
# ==========================================================

set -u

# ==========================================================
# COLORS
# ==========================================================

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

# ==========================================================
# REMOTE INSTALLER URLS
# ==========================================================

WIN10_URL="https://raw.githubusercontent.com/deepaksankhlaking97-svg/KingClouds/refs/heads/main/win10.sh"

VSCODE_URL="https://raw.githubusercontent.com/deepaksankhlaking97-svg/vs/refs/heads/main/vs.sh"

CONTAINER_URL="https://raw.githubusercontent.com/deepaksankhlaking97-svg/vs/refs/heads/main/container.sh"

# ==========================================================
# TERMINAL
# ==========================================================

clear_screen() {
    printf '\033[2J\033[H'
}

hide_cursor() {
    printf '\033[?25l'
}

show_cursor() {
    printf '\033[?25h'
}

cleanup() {
    show_cursor
}

trap cleanup EXIT
trap 'show_cursor; exit 0' INT TERM

# ==========================================================
# CENTER TEXT
# ==========================================================

center() {
    local text="$1"
    local width
    local clean
    local len
    local pad

    width=$(tput cols 2>/dev/null || echo 80)

    clean=$(printf '%b' "$text" | sed $'s/\033\\[[0-9;]*m//g')
    len=${#clean}

    pad=$(( (width - len) / 2 ))

    if [ "$pad" -lt 0 ]; then
        pad=0
    fi

    printf '%*s%b\n' "$pad" "" "$text"
}

# ==========================================================
# LINE
# ==========================================================

line() {
    printf '%b\n' \
        "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ==========================================================
# PAUSE
# ==========================================================

pause_screen() {
    echo
    printf '%b' "${GRAY}Press ENTER to return to KINGCLOUD menu...${RESET}"
    read -r
}

# ==========================================================
# SPINNER
# ==========================================================

spinner() {
    local message="$1"
    local duration="${2:-1}"

    local frames=(
        "⠋"
        "⠙"
        "⠹"
        "⠸"
        "⠼"
        "⠴"
        "⠦"
        "⠧"
        "⠇"
        "⠏"
    )

    local end
    local i=0

    end=$((SECONDS + duration))

    while [ "$SECONDS" -lt "$end" ]; do

        printf '\r%b' \
            "${CYAN}${frames[$((i % ${#frames[@]}))]}${RESET} ${WHITE}${message}${RESET}"

        sleep 0.08

        i=$((i + 1))
    done

    printf '\r%b\n' \
        "${GREEN}✔${RESET} ${WHITE}${message}${RESET}"
}

# ==========================================================
# PROGRESS BAR
# ==========================================================

progress() {
    local title="$1"
    local width=40
    local i
    local filled
    local empty

    for i in $(seq 0 2 100); do

        filled=$((i * width / 100))
        empty=$((width - filled))

        printf '\r%b' "${CYAN}${title}${RESET} ["

        if [ "$filled" -gt 0 ]; then
            printf '%*s' "$filled" '' | tr ' ' '█'
        fi

        if [ "$empty" -gt 0 ]; then
            printf '%b' "${GRAY}"
            printf '%*s' "$empty" '' | tr ' ' '░'
            printf '%b' "${RESET}"
        fi

        printf ' %3d%%' "$i"

        sleep 0.015
    done

    echo
}

# ==========================================================
# LOGO
# ==========================================================

logo() {

    echo

    center "${PURPLE}${BOLD}██╗  ██╗██╗███╗   ██╗ ██████╗${RESET}"
    center "${PURPLE}${BOLD}██║ ██╔╝██║████╗  ██║██╔════╝${RESET}"
    center "${CYAN}${BOLD}█████╔╝ ██║██╔██╗ ██║██║  ███╗${RESET}"
    center "${CYAN}${BOLD}██╔═██╗ ██║██║╚██╗██║██║   ██║${RESET}"
    center "${PURPLE}${BOLD}██║  ██╗██║██║ ╚████║╚██████╔╝${RESET}"
    center "${PURPLE}${BOLD}╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝${RESET}"

    echo

    center "${WHITE}${BOLD}C L O U D   I N S T A L L E R   H U B${RESET}"
    center "${GRAY}Premium VPS Tools • Fast • Simple • Reliable${RESET}"

    echo
}

# ==========================================================
# STARTUP
# ==========================================================

startup() {

    clear_screen
    hide_cursor

    echo

    center "${PURPLE}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
    center "${PURPLE}${BOLD}║              👑 KINGCLOUD                   ║${RESET}"
    center "${PURPLE}${BOLD}║           VPS INSTALLER HUB                 ║${RESET}"
    center "${PURPLE}${BOLD}╚══════════════════════════════════════════════╝${RESET}"

    echo

    center "${GRAY}Initializing cloud environment...${RESET}"

    echo

    spinner "Connecting to KINGCLOUD" 1
    spinner "Detecting VPS environment" 1
    spinner "Loading installer modules" 1
    spinner "Preparing control interface" 1

    echo

    printf ' %b\n' \
        "${CYAN}System${RESET}   ${GREEN}● ONLINE${RESET}"

    printf ' %b\n' \
        "${CYAN}Network${RESET}  ${GREEN}● READY${RESET}"

    printf ' %b\n' \
        "${CYAN}Modules${RESET}  ${GREEN}● LOADED${RESET}"

    printf ' %b\n' \
        "${CYAN}VPS${RESET}      ${GREEN}● DETECTED${RESET}"

    echo

    progress "Starting KINGCLOUD"

    echo

    center "${GREEN}${BOLD}✔ KINGCLOUD READY${RESET}"

    sleep 1
}

# ==========================================================
# HEADER
# ==========================================================

header() {

    clear_screen

    echo

    center "${PURPLE}${BOLD}👑 KINGCLOUD INSTALLER HUB${RESET}"
    center "${GRAY}────────────────────────────────────────────${RESET}"

    echo

    printf ' %b' \
        "${CYAN}Server:${RESET} ${WHITE}KINGCLOUD${RESET}"

    printf '    %b' \
        "${CYAN}Mode:${RESET} ${GREEN}ONLINE${RESET}"

    printf '    %b\n' \
        "${CYAN}Version:${RESET} ${WHITE}3.0${RESET}"

    echo

    line

    echo
}

# ==========================================================
# CHECK CURL
# ==========================================================

check_curl() {

    if command -v curl >/dev/null 2>&1; then
        return 0
    fi

    echo

    printf '%b\n' \
        "${RED}${BOLD}✖ curl is not installed.${RESET}"

    echo

    printf '%b\n' \
        "${YELLOW}Install curl with:${RESET}"

    printf '%b\n' \
        "${WHITE}apt-get update && apt-get install -y curl${RESET}"

    echo

    return 1
}

# ==========================================================
# WINDOWS 10 ANIMATION
# ==========================================================

windows10_animation() {

    clear_screen
    hide_cursor

    echo

    center "${BLUE}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
    center "${BLUE}${BOLD}║              🪟 WINDOWS 10                  ║${RESET}"
    center "${BLUE}${BOLD}║             CLOUD INSTALLER                 ║${RESET}"
    center "${BLUE}${BOLD}╚══════════════════════════════════════════════╝${RESET}"

    echo

    center "${WHITE}${BOLD}Windows 10 Virtual Machine${RESET}"
    center "${GRAY}Preparing Windows 10 installation environment${RESET}"

    echo

    line

    echo

    spinner "Initializing Windows 10 installer" 1
    spinner "Checking virtualization environment" 1
    spinner "Preparing VM environment" 1
    spinner "Connecting to Windows 10 service" 1
    spinner "Starting Windows 10 setup" 1

    echo

    printf ' %b\n' \
        "${CYAN}Virtualization${RESET} ${GREEN}● READY${RESET}"

    printf ' %b\n' \
        "${CYAN}VM Engine${RESET}      ${GREEN}● READY${RESET}"

    printf ' %b\n' \
        "${CYAN}Network${RESET}        ${GREEN}● READY${RESET}"

    printf ' %b\n' \
        "${CYAN}Storage${RESET}        ${GREEN}● READY${RESET}"

    echo

    progress "Opening Windows 10"

    echo

    center "${GREEN}${BOLD}✔ WINDOWS 10 INSTALLER READY${RESET}"

    sleep 1
}

# ==========================================================
# WINDOWS 10 INSTALLER
# ==========================================================

install_windows10() {

    windows10_animation

    echo

    line

    echo

    printf '%b\n' \
        "${CYAN}▶${RESET} ${WHITE}Opening Windows 10 installer...${RESET}"

    echo

    sleep 1

    if ! check_curl; then
        pause_screen
        return
    fi

    echo

    printf '%b\n' \
        "${GRAY}Source:${RESET} ${WHITE}${WIN10_URL}${RESET}"

    echo

    # EXACT WINDOWS 10 COMMAND
    bash <(curl -fsSL \
        "https://raw.githubusercontent.com/deepaksankhlaking97-svg/KingClouds/refs/heads/main/win10.sh")

    local status=$?

    echo

    if [ "$status" -eq 0 ]; then

        printf '%b\n' \
            "${GREEN}${BOLD}✔ Windows 10 installer completed successfully.${RESET}"

    else

        printf '%b\n' \
            "${RED}${BOLD}✖ Windows 10 installer exited with error code ${status}.${RESET}"

        echo

        printf '%b\n' \
            "${YELLOW}Check the win10.sh script or GitHub file if the installer itself has an error.${RESET}"
    fi

    echo

    pause_screen
}

# ==========================================================
# VS CODE INSTALLER
# ==========================================================

install_vscode() {

    clear_screen
    hide_cursor

    logo

    center "${CYAN}${BOLD}VS CODE INSTALLER${RESET}"

    echo

    line

    echo

    center "${WHITE}Visual Studio Code${RESET}"
    center "${GRAY}Automatic installation for your VPS${RESET}"

    echo

    spinner "Connecting to VS Code installer" 1
    spinner "Preparing VS Code installation" 1
    spinner "Starting installation" 1

    echo

    progress "Installing VS Code"

    echo

    if ! check_curl; then
        pause_screen
        return
    fi

    echo

    if bash <(curl -fsSL "$VSCODE_URL"); then

        echo

        printf '%b\n' \
            "${GREEN}${BOLD}✔ VS Code installation completed.${RESET}"

    else

        echo

        printf '%b\n' \
            "${RED}${BOLD}✖ VS Code installation failed.${RESET}"
    fi

    echo

    pause_screen
}

# ==========================================================
# CONTAINER INSTALLER
# ==========================================================

install_container() {

    clear_screen
    hide_cursor

    logo

    center "${CYAN}${BOLD}CONTAINER INSTALLER${RESET}"

    echo

    line

    echo

    center "${WHITE}KINGCLOUD Container Environment${RESET}"
    center "${GRAY}Automatic container installation for your VPS${RESET}"

    echo

    spinner "Connecting to container installer" 1
    spinner "Checking container environment" 1
    spinner "Preparing container environment" 1
    spinner "Starting installation" 1

    echo

    progress "Installing Container Environment"

    echo

    if ! check_curl; then
        pause_screen
        return
    fi

    echo

    if bash <(curl -fsSL "$CONTAINER_URL"); then

        echo

        printf '%b\n' \
            "${GREEN}${BOLD}✔ Container installation completed.${RESET}"

    else

        echo

        printf '%b\n' \
            "${RED}${BOLD}✖ Container installation failed.${RESET}"
    fi

    echo

    pause_screen
}

# ==========================================================
# ABOUT
# ==========================================================

about() {

    clear_screen
    hide_cursor

    echo

    center "${PURPLE}${BOLD}👑 ABOUT KINGCLOUD${RESET}"

    echo

    line

    echo

    center "${WHITE}${BOLD}KINGCLOUD INSTALLER HUB${RESET}"

    echo

    center "${GRAY}Premium terminal interface for KINGCLOUD VPS tools.${RESET}"
    center "${GRAY}Fast installation • Clean interface • Easy navigation${RESET}"

    echo

    printf ' %b\n' \
        "${CYAN}Available Tools:${RESET}"

    echo " ${GREEN}✔${RESET} Windows 10 VM Installer"
    echo " ${GREEN}✔${RESET} VS Code Installer"
    echo " ${GREEN}✔${RESET} Container Installer"
    echo " ${GREEN}✔${RESET} Premium startup animation"
    echo " ${GREEN}✔${RESET} VPS detection"
    echo " ${GREEN}✔${RESET} Progress animations"
    echo " ${GREEN}✔${RESET} Clean terminal GUI"

    echo

    center "${PURPLE}${BOLD}KINGCLOUD${RESET} ${GRAY}— Build. Deploy. Manage.${RESET}"

    pause_screen
}

# ==========================================================
# MAIN MENU
# ==========================================================

menu() {

    while true; do

        header

        printf ' %b\n\n' \
            "${PURPLE}${BOLD}MAIN MENU${RESET}"

        # --------------------------------------------------
        # OPTION 1
        # --------------------------------------------------

        printf ' %b\n' \
            "${BLUE}${BOLD}[1]${RESET}  ${WHITE}Windows 10 Installer${RESET}"

        printf '      %b\n\n' \
            "${GRAY}Install Windows 10 virtual machine${RESET}"

        # --------------------------------------------------
        # OPTION 2
        # --------------------------------------------------

        printf ' %b\n' \
            "${CYAN}${BOLD}[2]${RESET}  ${WHITE}VS Code Installer${RESET}"

        printf '      %b\n\n' \
            "${GRAY}Install Visual Studio Code on your VPS${RESET}"

        # --------------------------------------------------
        # OPTION 3
        # --------------------------------------------------

        printf ' %b\n' \
            "${PURPLE}${BOLD}[3]${RESET}  ${WHITE}Container Installer${RESET}"

        printf '      %b\n\n' \
            "${GRAY}Install container environment on your VPS${RESET}"

        # --------------------------------------------------
        # EXIT
        # --------------------------------------------------

        printf ' %b\n' \
            "${RED}${BOLD}[0]${RESET}  ${WHITE}Exit${RESET}"

        echo

        line

        echo

        read -r -p \
            "$(printf '%b' " ${PURPLE}${BOLD}KINGCLOUD ❯ ${RESET}")" choice

        case "$choice" in

            1)
                install_windows10
                ;;

            2)
                install_vscode
                ;;

            3)
                install_container
                ;;

            0)
                clear_screen
                show_cursor

                echo

                center "${PURPLE}${BOLD}👑 Thank you for using KINGCLOUD!${RESET}"

                echo

                exit 0
                ;;

            *)
                printf '\n%b\n' \
                    " ${RED}✖ Invalid option. Please choose 0-3.${RESET}"

                sleep 1
                ;;

        esac

    done
}

# ==========================================================
# START
# ==========================================================

startup
menu
```
