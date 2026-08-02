```bash
#!/bin/bash
set -euo pipefail

# ================================================================
#                    ZyroCloud Installer
#                         KVM MAKER
# ================================================================

# -------------------- PURPLE THEME --------------------
PURPLE='\033[1;35m'
LIGHT_PURPLE='\033[0;95m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
WHITE='\033[1;37m'
RESET='\033[0m'

# -------------------- CONFIG --------------------
VM_DIR="${VM_DIR:-$HOME/vms}"
mkdir -p "$VM_DIR"

# -------------------- ANIMATION --------------------
loading_animation() {
    local text="${1:-Starting ZyroCloud Installer}"
    local duration="${2:-1}"

    printf "${PURPLE}"
    printf "%s" "$text"

    local frames=("." ".." "..." "....")
    local end=$((SECONDS + duration))

    while [ "$SECONDS" -lt "$end" ]; do
        for frame in "${frames[@]}"; do
            printf "\r${PURPLE}%s%s${RESET} " "$text" "$frame"
            sleep 0.15

            if [ "$SECONDS" -ge "$end" ]; then
                break
            fi
        done
    done

    printf "\r${GREEN}%s... DONE${RESET}\n" "$text"
}

# -------------------- HEADER --------------------
display_header() {
    clear

    echo -e "${PURPLE}"
    cat <<'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║              ███████╗██╗   ██╗██████╗  ██████╗                     ║
║              ╚══███╔╝╚██╗ ██╔╝██╔══██╗██╔═══██╗                    ║
║                ███╔╝  ╚████╔╝ ██████╔╝██║   ██║                    ║
║               ███╔╝    ╚██╔╝  ██╔══██╗██║   ██║                    ║
║              ███████╗   ██║   ██║  ██║╚██████╔╝                    ║
║              ╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝                     ║
║                                                                      ║
║                    ZYROCLOUD INSTALLER                               ║
║                         KVM MAKER                                    ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${RESET}"
}

# -------------------- STATUS --------------------
print_status() {
    local type="$1"
    local message="$2"

    case "$type" in
        INFO)
            echo -e "${BLUE}[INFO]${RESET} $message"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${RESET} $message"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${RESET} $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${RESET} $message"
            ;;
        INPUT)
            echo -e "${LIGHT_PURPLE}[INPUT]${RESET} $message"
            ;;
        *)
            echo -e "${PURPLE}[$type]${RESET} $message"
            ;;
    esac
}

# -------------------- INPUT VALIDATION --------------------
validate_input() {
    local type="$1"
    local value="$2"

    case "$type" in

        number)
            [[ "$value" =~ ^[0-9]+$ ]] || {
                print_status ERROR "Must be a number"
                return 1
            }
            ;;

        size)
            [[ "$value" =~ ^[0-9]+[GgMm]$ ]] || {
                print_status ERROR "Use a size like 20G or 512M"
                return 1
            }
            ;;

        port)
            if ! [[ "$value" =~ ^[0-9]+$ ]] ||
               [ "$value" -lt 23 ] ||
               [ "$value" -gt 65535 ]; then

                print_status ERROR "Port must be between 23 and 65535"
                return 1
            fi
            ;;

        name)
            [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]] || {
                print_status ERROR "Use only letters, numbers, - and _"
                return 1
            }
            ;;

        username)
            [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]] || {
                print_status ERROR "Invalid Linux username"
                return 1
            }
            ;;

    esac

    return 0
}

# ================================================================
#                         KVM INSTALLER
# ================================================================

install_kvm() {

    display_header

    print_status INFO "Checking operating system..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        print_status INFO "Detected: ${PRETTY_NAME:-Unknown}"
    else
        print_status ERROR "Cannot detect operating system"
        return 1
    fi

    echo

    print_status INFO "Installing KVM/QEMU dependencies..."
    echo

    loading_animation "Updating package lists" 2

    if command -v apt-get >/dev/null 2>&1; then

        export DEBIAN_FRONTEND=noninteractive

        apt-get update -y

        apt-get install -y \
            qemu-system-x86 \
            qemu-utils \
            cloud-image-utils \
            wget \
            curl \
            openssl \
            iproute2 \
            procps \
            ca-certificates

    elif command -v dnf >/dev/null 2>&1; then

        dnf install -y \
            qemu-system-x86 \
            qemu-img \
            cloud-utils \
            wget \
            curl \
            openssl \
            iproute \
            procps \
            ca-certificates

    elif command -v yum >/dev/null 2>&1; then

        yum install -y \
            qemu-system-x86 \
            qemu-img \
            cloud-utils \
            wget \
            curl \
            openssl \
            iproute \
            procps \
            ca-certificates

    else
        print_status ERROR "Unsupported package manager."
        print_status INFO "Use Ubuntu/Debian, Fedora, AlmaLinux, Rocky Linux or CentOS."
        return 1
    fi

    echo
    loading_animation "Checking KVM installation" 2

    local missing=()

    command -v qemu-system-x86_64 >/dev/null 2>&1 || missing+=("qemu-system-x86_64")
    command -v qemu-img >/dev/null 2>&1 || missing+=("qemu-img")
    command -v wget >/dev/null 2>&1 || missing+=("wget")
    command -v cloud-localds >/dev/null 2>&1 || missing+=("cloud-localds")

    if [ "${#missing[@]}" -gt 0 ]; then
        print_status ERROR "Missing: ${missing[*]}"
        return 1
    fi

    echo
    print_status SUCCESS "KVM/QEMU installation completed!"
    echo

    # KVM hardware check
    if [ -e /dev/kvm ]; then
        print_status SUCCESS "/dev/kvm detected"
    else
        print_status WARN "/dev/kvm not detected"
        print_status WARN "QEMU may run using software emulation."
    fi

    echo

    read -rp "$(echo -e "${LIGHT_PURPLE}Press Enter to open KVM MAKER...${RESET}")"

    kvm_manager
}

# ================================================================
#                         VM FUNCTIONS
# ================================================================

cleanup() {
    rm -f user-data meta-data 2>/dev/null || true
}

get_vm_list() {
    find "$VM_DIR" -maxdepth 1 -name "*.conf" \
        -exec basename {} .conf \; 2>/dev/null | sort
}

load_vm_config() {

    local vm_name="$1"
    local config_file="$VM_DIR/$vm_name.conf"

    if [[ ! -f "$config_file" ]]; then
        print_status ERROR "VM '$vm_name' configuration not found"
        return 1
    fi

    unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
    unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS
    unset IMG_FILE SEED_FILE CREATED

    # shellcheck disable=SC1090
    source "$config_file"

    return 0
}

save_vm_config() {

    local config_file="$VM_DIR/$VM_NAME.conf"

    cat > "$config_file" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
EOF

    print_status SUCCESS "Configuration saved."
}

# ================================================================
#                         CREATE VM
# ================================================================

create_new_vm() {

    display_header

    print_status INFO "Create New Virtual Machine"
    echo

    local os_options=()
    local i=1

    for os in "${!OS_OPTIONS[@]}"; do
        echo -e "  ${PURPLE}$i)${RESET} $os"
        os_options[$i]="$os"
        ((i++))
    done

    echo

    while true; do

        read -rp "$(echo -e "${LIGHT_PURPLE}Select OS: ${RESET}")" choice

        if [[ "$choice" =~ ^[0-9]+$ ]] &&
           [ "$choice" -ge 1 ] &&
           [ "$choice" -le "${#OS_OPTIONS[@]}" ]; then

            local os="${os_options[$choice]}"

            IFS='|' read -r \
                OS_TYPE \
                CODENAME \
                IMG_URL \
                DEFAULT_HOSTNAME \
                DEFAULT_USERNAME \
                DEFAULT_PASSWORD \
                <<< "${OS_OPTIONS[$os]}"

            break

        else
            print_status ERROR "Invalid OS selection"
        fi

    done

    echo

    # VM Name
    while true; do

        read -rp "$(echo -e "${LIGHT_PURPLE}VM name [${DEFAULT_HOSTNAME}]: ${RESET}")" VM_NAME
        VM_NAME="${VM_NAME:-$DEFAULT_HOSTNAME}"

        if validate_input name "$VM_NAME"; then

            if [[ -f "$VM_DIR/$VM_NAME.conf" ]]; then
                print_status ERROR "VM '$VM_NAME' already exists"
            else
                break
            fi

        fi

    done

    # Hostname
    while true; do

        read -rp "$(echo -e "${LIGHT_PURPLE}Hostname [$VM_NAME]: ${RESET}")" HOSTNAME
        HOSTNAME="${HOSTNAME:-$VM_NAME}"

        validate_input name "$HOSTNAME" && break

    done

    # Username
    while true; do

        read -rp "$(echo -e "${LIGHT_PURPLE}Username [$DEFAULT_USERNAME]: ${RESET}")" USERNAME
        USERNAME="${USERNAME:-$DEFAULT_USERNAME}"

        validate_input username "$USERNAME" && break

    done

    # Password
    while true; do

        read -rsp "$(echo -e "${LIGHT_PURPLE}Password [default hidden]: ${RESET}")" PASSWORD
        echo

        PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"

        if [ -n "$PASSWORD" ]; then
            break
        fi

        print_status ERROR "Password cannot be empty"

    done

    # Disk
    while true; do

        read -rp "$(echo -e "${LIGHT_PURPLE}Disk size [20G]: ${RESET}")" DISK_SIZE
        DISK_SIZE="${DISK_SIZE:-20G}"

        validate_input size "$DISK_SIZE" && break

    done

    # RAM
    while true; do

        read -rp "$(echo -e "${LIGHT_PURPLE}RAM in MB [2048]: ${RESET}")" MEMORY
        MEMORY="${MEMORY:-2048}"

        validate_input number "$MEMORY" && break

    done

    # CPU
    while true; do

        read -rp "$(echo -e "${LIGHT_PURPLE}CPU cores [2]: ${RESET}")" CPUS
        CPUS="${CPUS:-2}"

        validate_input number "$CPUS" && break

    done

    # SSH
    while true; do

        read -rp "$(echo -e "${LIGHT_PURPLE}SSH port [2222]: ${RESET}")" SSH_PORT
        SSH_PORT="${SSH_PORT:-2222}"

        if validate_input port "$SSH_PORT"; then

            if ss -tln 2>/dev/null |
                grep -Eq "[:.]${SSH_PORT}[[:space:]]"; then

                print_status ERROR "Port $SSH_PORT is already in use"

            else
                break
            fi

        fi

    done

    # GUI
    while true; do

        read -rp "$(echo -e "${LIGHT_PURPLE}Enable GUI? (y/n) [n]: ${RESET}")" gui_input
        gui_input="${gui_input:-n}"

        if [[ "$gui_input" =~ ^[Yy]$ ]]; then
            GUI_MODE=true
            break
        elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
            GUI_MODE=false
            break
        else
            print_status ERROR "Enter y or n"
        fi

    done

    read -rp "$(echo -e "${LIGHT_PURPLE}Extra port forwards (example 8080:80): ${RESET}")" PORT_FORWARDS

    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"

    echo
    setup_vm_image
    save_vm_config

    print_status SUCCESS "VM '$VM_NAME' created."
}

# ================================================================
#                         IMAGE SETUP
# ================================================================

setup_vm_image() {

    mkdir -p "$VM_DIR"

    print_status INFO "Preparing VM image..."

    if [[ -f "$IMG_FILE" ]]; then

        print_status INFO "Existing image found."

    else

        print_status INFO "Downloading:"
        echo "$IMG_URL"
        echo

        wget --progress=bar:force \
            "$IMG_URL" \
            -O "$IMG_FILE.tmp"

        mv "$IMG_FILE.tmp" "$IMG_FILE"

    fi

    print_status INFO "Resizing disk to $DISK_SIZE..."

    qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null || true

    # Cloud-init
    local password_hash

    password_hash="$(openssl passwd -6 "$PASSWORD")"

    cat > user-data <<EOF
#cloud-config

hostname: $HOSTNAME
manage_etc_hosts: true

ssh_pwauth: true
disable_root: false

users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $password_hash

chpasswd:
  expire: false

runcmd:
  - systemctl enable ssh || true
  - systemctl restart ssh || true
EOF

    cat > meta-data <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    cloud-localds \
        "$SEED_FILE" \
        user-data \
        meta-data

    print_status SUCCESS "Cloud-init seed created."
}

# ================================================================
#                         VM RUNNING CHECK
# ================================================================

is_vm_running() {

    local vm_name="$1"

    load_vm_config "$vm_name" >/dev/null 2>&1 || return 1

    pgrep -f \
        "qemu-system-x86_64.*-name[ =]$vm_name" \
        >/dev/null 2>&1
}

# ================================================================
#                         START VM
# ================================================================

start_vm() {

    local vm_name="$1"

    load_vm_config "$vm_name" || return 1

    if is_vm_running "$vm_name"; then
        print_status WARN "VM '$vm_name' is already running."
        return 0
    fi

    if [[ ! -f "$IMG_FILE" ]]; then
        print_status ERROR "Image not found: $IMG_FILE"
        return 1
    fi

    if [[ ! -f "$SEED_FILE" ]]; then
        print_status WARN "Seed image missing. Recreating..."
        setup_vm_image
    fi

    print_status INFO "Starting VM: $VM_NAME"

    echo
    echo -e "${GREEN}SSH Command:${RESET}"
    echo -e "${WHITE}ssh -p $SSH_PORT $USERNAME@localhost${RESET}"
    echo
    echo -e "${GREEN}Password:${RESET} $PASSWORD"
    echo

    local qemu_cmd=(
        qemu-system-x86_64
        -name "$VM_NAME"
        -m "$MEMORY"
        -smp "$CPUS"
        -cpu qemu64
        -drive "file=$IMG_FILE,format=qcow2,if=virtio"
        -drive "file=$SEED_FILE,format=raw,if=virtio"
        -boot order=c
        -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22"
        -device "virtio-net-pci,netdev=n0"
        -device virtio-balloon-pci
        -object rng-random,filename=/dev/urandom,id=rng0
        -device virtio-rng-pci,rng=rng0
    )

    # Extra ports
    if [[ -n "${PORT_FORWARDS:-}" ]]; then

        local index=1

        IFS=',' read -ra forwards <<< "$PORT_FORWARDS"

        for forward in "${forwards[@]}"; do

            IFS=':' read -r host_port guest_port <<< "$forward"

            if validate_input port "$host_port" &&
               validate_input port "$guest_port"; then

                qemu_cmd+=(
                    -netdev "user,id=n$index,hostfwd=tcp::$host_port-:$guest_port"
                    -device "virtio-net-pci,netdev=n$index"
                )

                ((index++))

            else
                print_status WARN "Skipping invalid forward: $forward"
            fi

        done
    fi

    if [[ "$GUI_MODE" == true ]]; then

        qemu_cmd+=(
            -vga virtio
            -display gtk,gl=on
        )

    else

        qemu_cmd+=(
            -nographic
            -serial mon:stdio
        )

    fi

    echo
    print_status INFO "Launching QEMU..."
    echo

    "${qemu_cmd[@]}"

    print_status INFO "VM '$VM_NAME' stopped."
}

# ================================================================
#                         STOP VM
# ================================================================

stop_vm() {

    local vm_name="$1"

    load_vm_config "$vm_name" || return 1

    if ! is_vm_running "$vm_name"; then
        print_status INFO "VM '$vm_name' is not running."
        return 0
    fi

    print_status INFO "Stopping VM '$vm_name'..."

    pkill -TERM -f "qemu-system-x86_64.*-name[ =]$vm_name" || true

    sleep 3

    if is_vm_running "$vm_name"; then

        print_status WARN "VM did not stop gracefully."

        pkill -KILL -f "qemu-system-x86_64.*-name[ =]$vm_name" || true

    fi

    print_status SUCCESS "VM '$vm_name' stopped."
}

# ================================================================
#                         VM INFO
# ================================================================

show_vm_info() {

    local vm_name="$1"

    load_vm_config "$vm_name" || return 1

    echo
    echo -e "${PURPLE}════════════════ VM INFORMATION ════════════════${RESET}"

    echo -e "${CYAN}VM Name:${RESET}       $VM_NAME"
    echo -e "${CYAN}OS:${RESET}            $OS_TYPE"
    echo -e "${CYAN}Codename:${RESET}      $CODENAME"
    echo -e "${CYAN}Hostname:${RESET}      $HOSTNAME"
    echo -e "${CYAN}Username:${RESET}      $USERNAME"
    echo -e "${CYAN}Password:${RESET}      $PASSWORD"
    echo -e "${CYAN}SSH Port:${RESET}      $SSH_PORT"
    echo -e "${CYAN}RAM:${RESET}           $MEMORY MB"
    echo -e "${CYAN}CPU:${RESET}           $CPUS"
    echo -e "${CYAN}Disk:${RESET}          $DISK_SIZE"
    echo -e "${CYAN}GUI:${RESET}           $GUI_MODE"
    echo -e "${CYAN}Forward:${RESET}       ${PORT_FORWARDS:-None}"
    echo -e "${CYAN}Created:${RESET}       $CREATED"
    echo -e "${CYAN}Image:${RESET}         $IMG_FILE"
    echo -e "${CYAN}Seed:${RESET}          $SEED_FILE"

    echo -e "${PURPLE}════════════════════════════════════════════════${RESET}"
    echo

    read -rp "$(echo -e "${LIGHT_PURPLE}Press Enter...${RESET}")"
}

# ================================================================
#                         DELETE VM
# ================================================================

delete_vm() {

    local vm_name="$1"

    load_vm_config "$vm_name" || return 1

    print_status WARN "This will permanently delete '$vm_name'."
    echo

    read -rp "$(echo -e "${RED}Type DELETE to confirm: ${RESET}")" confirm

    if [[ "$confirm" != "DELETE" ]]; then
        print_status INFO "Deletion cancelled."
        return 0
    fi

    if is_vm_running "$vm_name"; then
        stop_vm "$vm_name"
    fi

    rm -f \
        "$IMG_FILE" \
        "$SEED_FILE" \
        "$VM_DIR/$vm_name.conf"

    print_status SUCCESS "VM '$vm_name' deleted."
}

# ================================================================
#                         RESIZE DISK
# ================================================================

resize_vm_disk() {

    local vm_name="$1"

    load_vm_config "$vm_name" || return 1

    echo
    print_status INFO "Current disk: $DISK_SIZE"

    while true; do

        read -rp "$(echo -e "${LIGHT_PURPLE}New disk size: ${RESET}")" new_disk_size

        if validate_input size "$new_disk_size"; then

            if is_vm_running "$vm_name"; then
                print_status ERROR "Stop the VM before resizing."
                return 1
            fi

            qemu-img resize "$IMG_FILE" "$new_disk_size"

            DISK_SIZE="$new_disk_size"

            save_vm_config

            print_status SUCCESS "Disk resized to $new_disk_size"
            break
        fi

    done
}

# ================================================================
#                         PERFORMANCE
# ================================================================

show_vm_performance() {

    local vm_name="$1"

    load_vm_config "$vm_name" || return 1

    if ! is_vm_running "$vm_name"; then

        print_status INFO "VM '$vm_name' is stopped."

        echo
        echo "RAM:  $MEMORY MB"
        echo "CPU:  $CPUS"
        echo "Disk: $DISK_SIZE"
        echo

        read -rp "$(echo -e "${LIGHT_PURPLE}Press Enter...${RESET}")"

        return
    fi

    local pid

    pid="$(pgrep -f "qemu-system-x86_64.*-name[ =]$vm_name" | head -n1 || true)"

    echo
    echo -e "${PURPLE}════════════ VM PERFORMANCE ════════════${RESET}"

    if [[ -n "$pid" ]]; then

        ps -p "$pid" \
            -o pid,%cpu,%mem,rss,vsz,etime,cmd \
            --no-headers

    fi

    echo
    echo "Host Memory:"
    free -h

    echo
    echo "Disk:"
    du -h "$IMG_FILE" 2>/dev/null || true

    echo -e "${PURPLE}═════════════════════════════════════════${RESET}"

    read -rp "$(echo -e "${LIGHT_PURPLE}Press Enter...${RESET}")"
}

# ================================================================
#                         EDIT VM
# ================================================================

edit_vm_config() {

    local vm_name="$1"

    load_vm_config "$vm_name" || return 1

    while true; do

        display_header

        echo -e "${PURPLE}VM: ${WHITE}$VM_NAME${RESET}"
        echo

        echo -e "  ${PURPLE}1)${RESET} Hostname"
        echo -e "  ${PURPLE}2)${RESET} Username"
        echo -e "  ${PURPLE}3)${RESET} Password"
        echo -e "  ${PURPLE}4)${RESET} SSH Port"
        echo -e "  ${PURPLE}5)${RESET} GUI Mode"
        echo -e "  ${PURPLE}6)${RESET} Port Forwards"
        echo -e "  ${PURPLE}7)${RESET} RAM"
        echo -e "  ${PURPLE}8)${RESET} CPU"
        echo -e "  ${PURPLE}9)${RESET} Disk"
        echo -e "  ${RED}0)${RESET} Back"

        echo

        read -rp "$(echo -e "${LIGHT_PURPLE}Select option: ${RESET}")" edit_choice

        case "$edit_choice" in

            1)
                read -rp "New hostname [$HOSTNAME]: " new_hostname
                new_hostname="${new_hostname:-$HOSTNAME}"

                if validate_input name "$new_hostname"; then
                    HOSTNAME="$new_hostname"
                fi
                ;;

            2)
                read -rp "New username [$USERNAME]: " new_username
                new_username="${new_username:-$USERNAME}"

                if validate_input username "$new_username"; then
                    USERNAME="$new_username"
                fi
                ;;

            3)
                read -rsp "New password: " new_password
                echo

                if [[ -n "$new_password" ]]; then
                    PASSWORD="$new_password"
                fi
                ;;

            4)
                read -rp "New SSH port [$SSH_PORT]: " new_port
                new_port="${new_port:-$SSH_PORT}"

                if validate_input port "$new_port"; then
                    SSH_PORT="$new_port"
                fi
                ;;

            5)
                read -rp "GUI? (y/n): " gui

                if [[ "$gui" =~ ^[Yy]$ ]]; then
                    GUI_MODE=true
                elif [[ "$gui" =~ ^[Nn]$ ]]; then
                    GUI_MODE=false
                fi
                ;;

            6)
                read -rp "Port forwards [$PORT_FORWARDS]: " pf
                PORT_FORWARDS="${pf:-$PORT_FORWARDS}"
                ;;

            7)
                read -rp "RAM MB [$MEMORY]: " ram

                if validate_input number "$ram"; then
                    MEMORY="$ram"
                fi
                ;;

            8)
                read -rp "CPU [$CPUS]: " cpu

                if validate_input number "$cpu"; then
                    CPUS="$cpu"
                fi
                ;;

            9)
                read -rp "Disk [$DISK_SIZE]: " disk

                if validate_input size "$disk"; then
                    DISK_SIZE="$disk"
                    qemu-img resize "$IMG_FILE" "$DISK_SIZE"
                fi
                ;;

            0)
                return
                ;;

            *)
                print_status ERROR "Invalid option"
                ;;

        esac

        save_vm_config

        if [[ "$edit_choice" == "1" ||
              "$edit_choice" == "2" ||
              "$edit_choice" == "3" ]]; then

            setup_vm_image
        fi

        read -rp "$(echo -e "${LIGHT_PURPLE}Press Enter...${RESET}")"

    done
}

# ================================================================
#                         VM SELECTOR
# ================================================================

select_vm() {

    local action="$1"

    mapfile -t vms < <(get_vm_list)

    if [ "${#vms[@]}" -eq 0 ]; then
        print_status WARN "No VMs found."
        return 1
    fi

    echo

    for i in "${!vms[@]}"; do

        local status="Stopped"

        if is_vm_running "${vms[$i]}"; then
            status="Running"
        fi

        echo -e "  ${PURPLE}$((i+1)))${RESET} ${vms[$i]} ${CYAN}[$status]${RESET}"

    done

    echo

    read -rp "$(echo -e "${LIGHT_PURPLE}Select VM: ${RESET}")" vm_num

    if ! [[ "$vm_num" =~ ^[0-9]+$ ]] ||
       [ "$vm_num" -lt 1 ] ||
       [ "$vm_num" -gt "${#vms[@]}" ]; then

        print_status ERROR "Invalid VM selection"
        return 1
    fi

    "$action" "${vms[$((vm_num-1))]}"
}

# ================================================================
#                         KVM MANAGER
# ================================================================

kvm_manager() {

    while true; do

        display_header

        mapfile -t vms < <(get_vm_list)

        echo -e "${CYAN}VM DIRECTORY:${RESET} $VM_DIR"
        echo

        if [ "${#vms[@]}" -gt 0 ]; then

            echo -e "${PURPLE}Existing VMs:${RESET}"

            for i in "${!vms[@]}"; do

                local status="Stopped"

                if is_vm_running "${vms[$i]}"; then
                    status="Running"
                fi

                printf "  ${PURPLE}%2d)${RESET} %-25s ${CYAN}%s${RESET}\n" \
                    "$((i+1))" \
                    "${vms[$i]}" \
                    "$status"
            done

            echo
        else
            print_status INFO "No virtual machines created yet."
            echo
        fi

        echo -e "${PURPLE}════════════════ KVM MAKER MENU ════════════════${RESET}"

        echo -e "  ${PURPLE}1)${RESET} Create New VM"

        if [ "${#vms[@]}" -gt 0 ]; then

            echo -e "  ${PURPLE}2)${RESET} Start VM"
            echo -e "  ${PURPLE}3)${RESET} Stop VM"
            echo -e "  ${PURPLE}4)${RESET} VM Information"
            echo -e "  ${PURPLE}5)${RESET} Edit VM"
            echo -e "  ${PURPLE}6)${RESET} Delete VM"
            echo -e "  ${PURPLE}7)${RESET} Resize Disk"
            echo -e "  ${PURPLE}8)${RESET} Performance"

        fi

        echo -e "  ${RED}0)${RESET} Exit"
        echo

        read -rp "$(echo -e "${LIGHT_PURPLE}Enter option: ${RESET}")" choice

        case "$choice" in

            1)
                loading_animation "Opening VM Creator" 1
                create_new_vm
                ;;

            2)
                [ "${#vms[@]}" -gt 0 ] && select_vm start_vm
                ;;

            3)
                [ "${#vms[@]}" -gt 0 ] && select_vm stop_vm
                ;;

            4)
                [ "${#vms[@]}" -gt 0 ] && select_vm show_vm_info
                ;;

            5)
                [ "${#vms[@]}" -gt 0 ] && select_vm edit_vm_config
                ;;

            6)
                [ "${#vms[@]}" -gt 0 ] && select_vm delete_vm
                ;;

            7)
                [ "${#vms[@]}" -gt 0 ] && select_vm resize_vm_disk
                ;;

            8)
                [ "${#vms[@]}" -gt 0 ] && select_vm show_vm_performance
                ;;

            0)
                echo
                loading_animation "Shutting down ZyroCloud KVM Maker" 1
                print_status SUCCESS "Goodbye!"
                exit 0
                ;;

            *)
                print_status ERROR "Invalid option"
                ;;

        esac

        echo
        read -rp "$(echo -e "${LIGHT_PURPLE}Press Enter to continue...${RESET}")"

    done
}

# ================================================================
#                         INITIAL MENU
# ================================================================

main_menu() {

    while true; do

        display_header

        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${PURPLE}║${RESET}                     ${WHITE}ZyroCloud Installer${RESET}                      ${PURPLE}║${RESET}"
        echo -e "${PURPLE}║${RESET}                          ${WHITE}KVM MAKER${RESET}                            ${PURPLE}║${RESET}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════╝${RESET}"

        echo
        echo -e "  ${PURPLE}1)${RESET} Install KVM"
        echo -e "  ${RED}0)${RESET} Exit"
        echo

        read -rp "$(echo -e "${LIGHT_PURPLE}Select option: ${RESET}")" option

        case "$option" in

            1)
                loading_animation "Starting ZyroCloud KVM Installer" 2

                if install_kvm; then
                    print_status SUCCESS "KVM is ready."
                else
                    print_status ERROR "KVM installation failed."
                    read -rp "$(echo -e "${LIGHT_PURPLE}Press Enter...${RESET}")"
                fi
                ;;

            0)
                echo
                loading_animation "Exiting ZyroCloud Installer" 1
                print_status SUCCESS "Bye!"
                exit 0
                ;;

            *)
                print_status ERROR "Invalid option. Use 1 or 0."
                sleep 1
                ;;

        esac

    done
}

# ================================================================
#                         OS LIST
# ================================================================

declare -A OS_OPTIONS=(

    ["Ubuntu 22.04"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"

    ["Ubuntu 24.04"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"

    ["Debian 11"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian|debian"

    ["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"

    ["Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"

    ["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"

    ["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|almalinux9|alma|alma"

    ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
)

# ================================================================
#                         START
# ================================================================

trap cleanup EXIT

main_menu
```
