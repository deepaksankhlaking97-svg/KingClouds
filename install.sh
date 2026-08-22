install_vscode() {
    clear_screen
    logo

    echo
    center "${CYAN}${BOLD}VS CODE INSTALLER${RESET}"
    echo
    line
    echo

    spinner "Preparing VS Code installation" 2
    spinner "Connecting to KINGCLOUD installer" 2
    progress "Installing VS Code"

    # Command is intentionally hidden from the UI.
    if bash <(curl -fsSL https://raw.githubusercontent.com/deepaksankhlaking97-svg/vs/refs/heads/main/vs.sh) >/tmp/kingcloud-vscode.log 2>&1; then
        echo
        printf "${GREEN}${BOLD}✔ VS Code installation completed successfully.${RESET}\n"
    else
        echo
        printf "${RED}${BOLD}✖ VS Code installation failed.${RESET}\n"
        printf "${GRAY}Check the installer log for details.${RESET}\n"
    fi

    pause_screen
}


install_container() {
    clear_screen
    logo

    echo
    center "${CYAN}${BOLD}CONTAINER INSTALLER${RESET}"
    echo
    line
    echo

    spinner "Preparing container environment" 2
    spinner "Connecting to KINGCLOUD installer" 2
    progress "Installing container environment"

    # Command is intentionally hidden from the UI.
    if bash <(curl -fsSL https://raw.githubusercontent.com/deepaksankhlaking97-svg/vs/refs/heads/main/container.sh) >/tmp/kingcloud-container.log 2>&1; then
        echo
        printf "${GREEN}${BOLD}✔ Container installation completed successfully.${RESET}\n"
    else
        echo
        printf "${RED}${BOLD}✖ Container installation failed.${RESET}\n"
        printf "${GRAY}Check the installer log for details.${RESET}\n"
    fi

    pause_screen
}
