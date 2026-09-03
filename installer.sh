#!/usr/bin/env bash

set -u

RESET="\033[0m"
BOLD="\033[1m"
PURPLE="\033[38;5;141m"
CYAN="\033[38;5;51m"
BLUE="\033[38;5;75m"
GREEN="\033[38;5;82m"
RED="\033[38;5;203m"
WHITE="\033[38;5;255m"
GRAY="\033[38;5;245m"

WIN10_URL="https://raw.githubusercontent.com/deepaksankhlaking97-svg/KingClouds/refs/heads/main/win10.sh"

clear_screen() {
    printf '\033[2J\033[H'
}

hide_cursor() {
    printf '\033[?25l'
}

show_cursor() {
    printf '\033[?25h'
}

trap 'show_cursor' EXIT
trap 'show_cursor; exit 0' INT TERM

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

    [ "$pad" -lt 0 ] && pad=0

    printf '%*s%b\n' "$pad" "" "$text"
}

line() {
    printf '%b\n' \
    "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

spinner() {
    local text="$1"
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0
    local end=$((SECONDS + 1))

    while [ "$SECONDS" -lt "$end" ]; do
        printf '\r%b' \
        "${CYAN}${frames[$((i % ${#frames[@]}))]}${RESET} ${WHITE}${text}${RESET}"
        sleep 0.08
        i=$((i + 1))
    done

    printf '\r%b\n' \
    "${GREEN}✔${RESET} ${WHITE}${text}${RESET}"
}

progress() {
    local title="$1"
    local width=35
    local i filled empty

    for i in $(seq 0 2 100); do

        filled=$((i * width / 100))
        empty=$((width - filled))

        printf '\r%b [' "${CYAN}${title}${RESET}"

        [ "$filled" -gt 0 ] &&
            printf '%*s' "$filled" '' | tr ' ' '█'

        [ "$empty" -gt 0 ] &&
            printf '%b' "${GRAY}" &&
            printf '%*s' "$empty" '' | tr ' ' '░' &&
            printf '%b' "${RESET}"

        printf '] %3d%%' "$i"

        sleep 0.01
    done

    echo
}

header() {
    clear_screen

    echo

    center "${PURPLE}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
    center "${PURPLE}${BOLD}║              👑 KINGCLOUD                   ║${RESET}"
    center "${PURPLE}${BOLD}║           INSTALLER HUB v3.0                ║${RESET}"
    center "${PURPLE}${BOLD}╚══════════════════════════════════════════════╝${RESET}"

    echo

    line

    echo

    printf '  %b\n' \
        "${GREEN}●${RESET} ${WHITE}KINGCLOUD SYSTEM ONLINE${RESET}"

    echo
}

pause_screen() {
    echo
    printf '%b' "${GRAY}Press ENTER to return...${RESET}"
    read -r
}

# ==========================================================
# WINDOWS 10
# ==========================================================

windows10() {

    clear_screen
    hide_cursor

    echo

    center "${BLUE}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
    center "${BLUE}${BOLD}║              🪟 WINDOWS 10                  ║${RESET}"
    center "${BLUE}${BOLD}║             INSTALLER STARTUP               ║${RESET}"
    center "${BLUE}${BOLD}╚══════════════════════════════════════════════╝${RESET}"

    echo

    line

    echo

    spinner "Initializing Windows 10 installer"
    spinner "Checking VPS environment"
    spinner "Checking network connection"
    spinner "Preparing Windows 10 environment"
    spinner "Connecting to KINGCLOUD installer"

    echo

    progress "Preparing Windows 10"

    echo

    printf '%b\n' \
        "${GREEN}${BOLD}✔ Windows 10 installer is starting...${RESET}"

    echo

    sleep 1

    # ------------------------------------------------------
    # REQUIRE CURL
    # ------------------------------------------------------

    if ! command -v curl >/dev/null 2>&1; then

        printf '%b\n' \
            "${RED}${BOLD}✖ curl is not installed.${RESET}"

        echo

        printf '%b\n' \
            "${YELLOW}Install it using:${RESET}"

        printf '%b\n' \
            "${WHITE}apt-get update && apt-get install -y curl${RESET}"

        pause_screen
        return

    fi

    # ------------------------------------------------------
    # TEMP FILE
    # ------------------------------------------------------

    local tmp

    tmp="$(mktemp /tmp/kingcloud-win10.XXXXXX.sh)"

    # ------------------------------------------------------
    # DOWNLOAD
    # ------------------------------------------------------

    printf '%b\n' \
        "${CYAN}▶${RESET} ${WHITE}Downloading Windows 10 installer...${RESET}"

    if ! curl -fsSL \
        --connect-timeout 15 \
        --max-time 300 \
        "$WIN10_URL" \
        -o "$tmp"; then

        echo

        printf '%b\n' \
            "${RED}${BOLD}✖ Failed to download win10.sh${RESET}"

        rm -f "$tmp"

        pause_screen
        return

    fi

    # ------------------------------------------------------
    # EMPTY FILE CHECK
    # ------------------------------------------------------

    if [ ! -s "$tmp" ]; then

        printf '%b\n' \
            "${RED}${BOLD}✖ Downloaded win10.sh is empty.${RESET}"

        rm -f "$tmp"

        pause_screen
        return

    fi

    # ------------------------------------------------------
    # BASIC BASH SYNTAX CHECK
    # ------------------------------------------------------

    printf '%b\n' \
        "${CYAN}▶${RESET} ${WHITE}Checking installer syntax...${RESET}"

    if ! bash -n "$tmp"; then

        echo

        printf '%b\n' \
            "${RED}${BOLD}✖ win10.sh contains a Bash syntax error.${RESET}"

        echo

        printf '%b\n' \
            "${GRAY}The launcher was stopped before executing the broken script.${RESET}"

        rm -f "$tmp"

        pause_screen
        return

    fi

    printf '%b\n' \
        "${GREEN}✔${RESET} ${WHITE}Installer syntax OK${RESET}"

    echo

    # ------------------------------------------------------
    # EXECUTE
    # ------------------------------------------------------

    printf '%b\n' \
        "${GREEN}${BOLD}▶ Starting Windows 10 installer...${RESET}"

    echo

    bash "$tmp"

    local status=$?

    # ------------------------------------------------------
    # CLEANUP
    # ------------------------------------------------------

    rm -f "$tmp"

    echo

    if [ "$status" -eq 0 ]; then

        printf '%b\n' \
            "${GREEN}${BOLD}✔ Windows 10 installer completed.${RESET}"

    else

        printf '%b\n' \
            "${RED}${BOLD}✖ Windows 10 installer stopped with exit code ${status}.${RESET}"

    fi

    pause_screen
}

# ==========================================================
# OPTION 2
# ==========================================================

option2() {

    clear_screen

    echo

    center "${CYAN}${BOLD}VS CODE INSTALLER${RESET}"

    echo
    line
    echo

    printf '%b\n' \
        "${YELLOW}VS Code installer can be added here.${RESET}"

    echo

    pause_screen
}

# ==========================================================
# OPTION 3
# ==========================================================

option3() {

    clear_screen

    echo

    center "${PURPLE}${BOLD}CONTAINER INSTALLER${RESET}"

    echo
    line
    echo

    printf '%b\n' \
        "${YELLOW}Container installer can be added here.${RESET}"

    echo

    pause_screen
}

# ==========================================================
# MAIN MENU
# ==========================================================

menu() {

    while true; do

        header

        printf '%b\n\n' \
            "${PURPLE}${BOLD}MAIN MENU${RESET}"

        printf '  %b\n' \
            "${BLUE}${BOLD}[1]${RESET} ${WHITE}Windows 10 Installer${RESET}"

        printf '      %b\n\n' \
            "${GRAY}Open Windows 10 installer${RESET}"

        printf '  %b\n' \
            "${CYAN}${BOLD}[2]${RESET} ${WHITE}VS Code Installer${RESET}"

        printf '      %b\n\n' \
            "${GRAY}Open VS Code installer${RESET}"

        printf '  %b\n' \
            "${PURPLE}${BOLD}[3]${RESET} ${WHITE}Container Installer${RESET}"

        printf '      %b\n\n' \
            "${GRAY}Open container installer${RESET}"

        printf '  %b\n' \
            "${RED}${BOLD}[0]${RESET} ${WHITE}Exit${RESET}"

        echo

        line

        echo

        read -r -p \
            "$(printf '%b' " ${PURPLE}${BOLD}KINGCLOUD ❯ ${RESET}")" choice

        case "$choice" in

            1)
                windows10
                ;;

            2)
                option2
                ;;

            3)
                option3
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
                    "${RED}✖ Invalid option. Choose 0-3.${RESET}"

                sleep 1
                ;;

        esac

    done
}

# ==========================================================
# STARTUP
# ==========================================================

startup() {

    clear_screen
    hide_cursor

    echo

    center "${PURPLE}${BOLD}KINGCLOUD${RESET}"
    center "${GRAY}Initializing Installer Hub...${RESET}"

    echo

    spinner "Starting KINGCLOUD"
    spinner "Loading modules"
    spinner "Checking terminal"

    echo

    progress "Loading"

    sleep 0.5

    menu
}

startup
