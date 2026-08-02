#!/bin/bash
set -Eeuo pipefail

# ================================================================
#                    ZYROCLOUD KVM MANAGER
# ================================================================
# Features:
# - Automatic KVM/QEMU installation
# - Existing KVM installation detection
# - Ubuntu/Debian cloud images
# - VM create/start/stop/restart/delete
# - Existing VMs auto-start
# - New VMs auto-start
# - Auto-start after host reboot
# - SSH port forwarding
# - Background QEMU
# - SSH details display
# ================================================================

APP_NAME="ZyroCloud KVM"
VM_DIR="/var/lib/zyrocloud-kvm/vms"
SERVICE_DIR="/etc/systemd/system"
AUTOSTART_SERVICE="zyrocloud-kvm-autostart.service"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; }
input()   { echo -en "${CYAN}[INPUT]${RESET} $*"; }

header() {
    clear
    cat <<'EOF'
======================================================================

  _______              ____ _                 _
 |__   __|             / ___| | ___  _   _  __| |
    | | ___ _ __ ___  | |   | |/ _ \| | | |/ _` |
    | |/ _ \ '__/ _ \ | |___| | (_) | |_| | (_| |
    | |  __/ | |  __/  \____|_|\___/ \__,_|\__,_|
    |_|\___|_|  \___|

                     ZYROCLOUD KVM
                  Virtual Machine Manager

======================================================================
EOF
    echo
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Please run this script as root."
        echo
        echo "Example:"
        echo "  sudo bash $0"
        exit 1
    fi
}

install_dependencies() {
    info "Checking KVM/QEMU installation..."

    local missing=()

    command -v qemu-system-x86_64 >/dev/null 2>&1 || missing+=("qemu-system-x86")
    command -v qemu-img >/dev/null 2>&1 || missing+=("qemu-utils")
    command -v cloud-localds >/dev/null 2>&1 || missing+=("cloud-image-utils")
    command -v wget >/dev/null 2>&1 || missing+=("wget")

    if [[ ${#missing[@]} -eq 0 ]]; then
        success "KVM/QEMU is already installed."
    else
        info "Installing missing packages: ${missing[*]}"

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

        success "KVM/QEMU installation completed."
    fi

    mkdir -p "$VM_DIR"
}

check_kvm() {
    if [[ -e /dev/kvm ]]; then
        success "Hardware KVM acceleration detected."
        return 0
    fi

    warn "/dev/kvm was not found."
    warn "QEMU can still run, but hardware acceleration may not be available."

    return 1
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release

        if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" ]]; then
            warn "This installer is optimized for Ubuntu/Debian."
        fi
    fi
}

declare -A OS_OPTIONS

OS_OPTIONS["Ubuntu 24.04"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu"
OS_OPTIONS["Ubuntu 22.04"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu"
OS_OPTIONS["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian"
OS_OPTIONS["Debian 11"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian"
OS_OPTIONS["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|alma"
OS_OPTIONS["Rocky Linux 9"]="rocky|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky"

get_vms() {
    find "$VM_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.conf" \
        -printf "%f\n" 2>/dev/null |
        sed 's/\.conf$//' |
        sort
}

vm_exists() {
    [[ -f "$VM_DIR/$1.conf" ]]
}

load_vm() {
    local name="$1"
    local file="$VM_DIR/$name.conf"

    if [[ ! -f "$file" ]]; then
        error "VM '$name' does not exist."
        return 1
    fi

    unset VM_NAME OS_TYPE CODENAME IMG_URL USERNAME PASSWORD
    unset HOSTNAME DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE
    unset IMG_FILE SEED_FILE CREATED AUTOSTART

    source "$file"
}

save_vm() {
    cat > "$VM_DIR/$VM_NAME.conf" <<EOF
VM_NAME=$(printf '%q' "$VM_NAME")
OS_TYPE=$(printf '%q' "$OS_TYPE")
CODENAME=$(printf '%q' "$CODENAME")
IMG_URL=$(printf '%q' "$IMG_URL")
HOSTNAME=$(printf '%q' "$HOSTNAME")
USERNAME=$(printf '%q' "$USERNAME")
PASSWORD=$(printf '%q' "$PASSWORD")
DISK_SIZE=$(printf '%q' "$DISK_SIZE")
MEMORY=$(printf '%q' "$MEMORY")
CPUS=$(printf '%q' "$CPUS")
SSH_PORT=$(printf '%q' "$SSH_PORT")
GUI_MODE=$(printf '%q' "$GUI_MODE")
IMG_FILE=$(printf '%q' "$IMG_FILE")
SEED_FILE=$(printf '%q' "$SEED_FILE")
CREATED=$(printf '%q' "$CREATED")
AUTOSTART=$(printf '%q' "$AUTOSTART")
EOF
}

valid_name() {
    [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]]
}

valid_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

port_available() {
    local port="$1"

    if ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"; then
        return 1
    fi

    return 0
}

find_free_port() {
    local port=2222

    while ! port_available "$port"; do
        ((port++))
    done

    echo "$port"
}

vm_pid_file() {
    echo "$VM_DIR/$1.pid"
}

is_running() {
    local name="$1"
    local pidfile
    pidfile="$(vm_pid_file "$name")"

    [[ -f "$pidfile" ]] || return 1

    local pid
    pid="$(cat "$pidfile" 2>/dev/null || true)"

    [[ -n "$pid" ]] || return 1

    kill -0 "$pid" 2>/dev/null
}

create_cloud_init() {
    local user_data="$VM_DIR/$VM_NAME-user-data"
    local meta_data="$VM_DIR/$VM_NAME-meta-data"

    local hashed_password
    hashed_password="$(openssl passwd -6 "$PASSWORD")"

    cat > "$user_data" <<EOF
#cloud-config

hostname: $HOSTNAME

manage_etc_hosts: true

ssh_pwauth: true

disable_root: false

users:
  - name: $USERNAME
    groups: sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $hashed_password

chpasswd:
  expire: false

runcmd:
  - systemctl enable ssh 2>/dev/null || true
  - systemctl enable sshd 2>/dev/null || true
EOF

    cat > "$meta_data" <<EOF
instance-id: zyrocloud-$VM_NAME
local-hostname: $HOSTNAME
EOF

    cloud-localds "$SEED_FILE" "$user_data" "$meta_data"

    rm -f "$user_data" "$meta_data"
}

download_image() {
    if [[ -f "$IMG_FILE" ]]; then
        info "Disk image already exists."
        return 0
    fi

    info "Downloading OS image..."
    info "$IMG_URL"

    local tmp="$IMG_FILE.download"

    rm -f "$tmp"

    wget \
        --progress=bar:force \
        --tries=3 \
        --timeout=30 \
        "$IMG_URL" \
        -O "$tmp"

    mv "$tmp" "$IMG_FILE"

    success "OS image downloaded."
}

prepare_disk() {
    info "Preparing disk: $DISK_SIZE"

    qemu-img resize "$IMG_FILE" "$DISK_SIZE"

    success "Disk prepared."
}

create_vm() {
    header

    info "Create a new ZyroCloud KVM VM"
    echo

    local names=()
    local i=1

    for os in "${!OS_OPTIONS[@]}"; do
        names[$i]="$os"
        echo "  $i) $os"
        ((i++))
    done

    echo

    local choice

    while true; do
        input "Select OS: "
        read -r choice

        if [[ "$choice" =~ ^[0-9]+$ ]] &&
           (( choice >= 1 && choice < i )); then
            break
        fi

        error "Invalid OS selection."
    done

    local selected="${names[$choice]}"

    IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_USER <<< "${OS_OPTIONS[$selected]}"

    echo

    while true; do
        input "VM name: "
        read -r VM_NAME

        VM_NAME="${VM_NAME:-$CODENAME-vm}"

        if ! valid_name "$VM_NAME"; then
            error "Invalid VM name."
            continue
        fi

        if vm_exists "$VM_NAME"; then
            error "VM '$VM_NAME' already exists."
            continue
        fi

        break
    done

    input "Hostname [$VM_NAME]: "
    read -r HOSTNAME
    HOSTNAME="${HOSTNAME:-$VM_NAME}"

    input "Username [$DEFAULT_USER]: "
    read -r USERNAME
    USERNAME="${USERNAME:-$DEFAULT_USER}"

    while true; do
        input "Password: "
        read -rs PASSWORD
        echo

        if [[ -n "$PASSWORD" ]]; then
            break
        fi

        error "Password cannot be empty."
    done

    input "Disk size [20G]: "
    read -r DISK_SIZE
    DISK_SIZE="${DISK_SIZE:-20G}"

    if ! [[ "$DISK_SIZE" =~ ^[0-9]+[GgMm]$ ]]; then
        error "Invalid disk size."
        return 1
    fi

    input "RAM in MB [2048]: "
    read -r MEMORY
    MEMORY="${MEMORY:-2048}"

    if ! valid_number "$MEMORY"; then
        error "Invalid RAM."
        return 1
    fi

    input "CPU cores [2]: "
    read -r CPUS
    CPUS="${CPUS:-2}"

    if ! valid_number "$CPUS"; then
        error "Invalid CPU count."
        return 1
    fi

    SSH_PORT="$(find_free_port)"

    echo
    info "Automatically selected SSH port: $SSH_PORT"

    input "GUI mode? [n]: "
    read -r gui

    GUI_MODE=false

    if [[ "$gui" =~ ^[Yy]$ ]]; then
        GUI_MODE=true
    fi

    AUTOSTART=true

    IMG_FILE="$VM_DIR/$VM_NAME.qcow2"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date '+%Y-%m-%d %H:%M:%S')"

    echo
    info "Creating VM files..."

    download_image
    prepare_disk
    create_cloud_init
    save_vm

    success "VM '$VM_NAME' created."

    echo
    start_vm "$VM_NAME"
}

build_qemu_command() {
    local name="$1"

    load_vm "$name"

    QEMU_CMD=(
        qemu-system-x86_64

        -name "zyrocloud-$VM_NAME"

        -machine type=q35,accel=kvm:tcg

        -cpu host

        -m "$MEMORY"

        -smp "$CPUS"

        -drive "file=$IMG_FILE,if=virtio,format=qcow2,cache=writeback,aio=threads"

        -drive "file=$SEED_FILE,if=virtio,format=raw,readonly=on"

        -boot order=c

        -device virtio-net-pci,netdev=net0

        -netdev "user,id=net0,hostfwd=tcp:0.0.0.0:$SSH_PORT-:22"

        -device virtio-balloon-pci

        -object rng-random,filename=/dev/urandom,id=rng0

        -device virtio-rng-pci,rng=rng0

        -no-reboot

        -daemonize

        -pidfile "$(vm_pid_file "$VM_NAME")"

        -monitor "unix:$VM_DIR/$VM_NAME-monitor.sock,server,nowait"
    )

    if [[ "$GUI_MODE" == true ]]; then
        QEMU_CMD+=(
            -vga virtio
        )
    else
        QEMU_CMD+=(
            -nographic
        )
    fi
}

start_vm() {
    local name="$1"

    if ! load_vm "$name"; then
        return 1
    fi

    if is_running "$name"; then
        warn "VM '$name' is already running."
        show_ssh "$name"
        return 0
    fi

    if [[ ! -f "$IMG_FILE" ]]; then
        error "Disk image missing."
        return 1
    fi

    if [[ ! -f "$SEED_FILE" ]]; then
        warn "Cloud-init seed missing. Recreating..."
        create_cloud_init
    fi

    if ! port_available "$SSH_PORT"; then
        error "SSH port $SSH_PORT is already in use."
        return 1
    fi

    info "Starting VM: $name"

    build_qemu_command "$name"

    "${QEMU_CMD[@]}"

    sleep 2

    if is_running "$name"; then
        success "VM '$name' started."
        show_ssh "$name"
    else
        error "VM failed to start."
        return 1
    fi
}

stop_vm() {
    local name="$1"

    if ! load_vm "$name"; then
        return 1
    fi

    if ! is_running "$name"; then
        info "VM '$name' is already stopped."
        return 0
    fi

    local pid
    pid="$(cat "$(vm_pid_file "$name")")"

    info "Stopping VM '$name'..."

    kill "$pid" 2>/dev/null || true

    for _ in {1..10}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        sleep 1
    done

    if kill -0 "$pid" 2>/dev/null; then
        warn "Graceful stop failed. Force stopping..."
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$(vm_pid_file "$name")"

    success "VM '$name' stopped."
}

restart_vm() {
    local name="$1"

    stop_vm "$name"
    sleep 1
    start_vm "$name"
}

show_ssh() {
    local name="$1"

    load_vm "$name"

    echo
    echo "=============================================================="
    echo "                  ZYROCLOUD VM SSH"
    echo "=============================================================="
    echo
    echo "VM       : $VM_NAME"
    echo "Hostname : $HOSTNAME"
    echo "OS       : $OS_TYPE $CODENAME"
    echo
    echo "SSH Host : $(hostname -I | awk '{print $1}')"
    echo "SSH Port : $SSH_PORT"
    echo "Username : $USERNAME"
    echo "Password : $PASSWORD"
    echo
    echo "SSH Command:"
    echo
    echo "ssh -p $SSH_PORT $USERNAME@$(hostname -I | awk '{print $1}')"
    echo
    echo "=============================================================="
}

show_info() {
    local name="$1"

    load_vm "$name"

    echo
    echo "=============================================================="
    echo "VM INFORMATION"
    echo "=============================================================="
    echo "Name       : $VM_NAME"
    echo "OS         : $OS_TYPE"
    echo "Codename   : $CODENAME"
    echo "Hostname   : $HOSTNAME"
    echo "Username   : $USERNAME"
    echo "SSH Port   : $SSH_PORT"
    echo "RAM        : ${MEMORY} MB"
    echo "CPU        : $CPUS"
    echo "Disk       : $DISK_SIZE"
    echo "Autostart  : $AUTOSTART"
    echo "Created    : $CREATED"
    echo "Status     : $(is_running "$name" && echo Running || echo Stopped)"
    echo "Disk Image : $IMG_FILE"
    echo "=============================================================="
}

delete_vm() {
    local name="$1"

    load_vm "$name"

    echo
    warn "This will permanently delete VM '$name'."
    input "Type DELETE to continue: "
    read -r confirm

    [[ "$confirm" == "DELETE" ]] || {
        info "Deletion cancelled."
        return
    }

    if is_running "$name"; then
        stop_vm "$name"
    fi

    rm -f \
        "$VM_DIR/$name.conf" \
        "$VM_DIR/$name.qcow2" \
        "$VM_DIR/$name-seed.iso" \
        "$VM_DIR/$name.pid" \
        "$VM_DIR/$name-monitor.sock"

    success "VM '$name' deleted."
}

autostart_vms() {
    info "ZyroCloud: starting existing VMs..."

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue

        if load_vm "$name"; then
            if [[ "${AUTOSTART:-true}" == true ]]; then
                if ! is_running "$name"; then
                    start_vm "$name" || warn "Failed to start $name"
                else
                    info "$name is already running."
                fi
            fi
        fi
    done < <(get_vms)

    success "ZyroCloud VM auto-start completed."
}

install_autostart_service() {
    info "Installing ZyroCloud auto-start service..."

    cat > "$SERVICE_DIR/$AUTOSTART_SERVICE" <<EOF
[Unit]
Description=ZyroCloud KVM Auto Start
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$0 --autostart
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$SERVICE_DIR/$AUTOSTART_SERVICE"

    systemctl daemon-reload
    systemctl enable "$AUTOSTART_SERVICE" >/dev/null 2>&1 || true

    success "Auto-start service enabled."
}

edit_vm() {
    local name="$1"

    load_vm "$name"

    echo
    echo "1) RAM"
    echo "2) CPU"
    echo "3) SSH Port"
    echo "4) Password"
    echo "5) Autostart"
    echo "0) Back"
    echo

    input "Choice: "
    read -r choice

    case "$choice" in
        1)
            input "New RAM [$MEMORY]: "
            read -r value
            value="${value:-$MEMORY}"

            if valid_number "$value"; then
                MEMORY="$value"
                save_vm
                success "RAM updated."
            else
                error "Invalid RAM."
            fi
            ;;

        2)
            input "New CPU count [$CPUS]: "
            read -r value
            value="${value:-$CPUS}"

            if valid_number "$value"; then
                CPUS="$value"
                save_vm
                success "CPU count updated."
            else
                error "Invalid CPU count."
            fi
            ;;

        3)
            input "New SSH port [$SSH_PORT]: "
            read -r value
            value="${value:-$SSH_PORT}"

            if port_available "$value"; then
                SSH_PORT="$value"
                save_vm
                success "SSH port updated."
            else
                error "Port is already in use."
            fi
            ;;

        4)
            input "New password: "
            read -rs value
            echo

            if [[ -n "$value" ]]; then
                PASSWORD="$value"
                create_cloud_init
                save_vm
                success "Password configuration updated."
            fi
            ;;

        5)
            if [[ "${AUTOSTART:-true}" == true ]]; then
                AUTOSTART=false
            else
                AUTOSTART=true
            fi

            save_vm
            success "Autostart: $AUTOSTART"
            ;;

        0)
            return
            ;;

        *)
            error "Invalid option."
            ;;
    esac
}

select_vm() {
    local action="$1"

    mapfile -t VMS < <(get_vms)

    if [[ ${#VMS[@]} -eq 0 ]]; then
        warn "No VMs found."
        return 1
    fi

    echo

    local i=1

    for vm in "${VMS[@]}"; do
        if is_running "$vm"; then
            printf " %2d) %-25s [RUNNING]\n" "$i" "$vm"
        else
            printf " %2d) %-25s [STOPPED]\n" "$i" "$vm"
        fi

        ((i++))
    done

    echo

    input "Select VM: "
    read -r number

    if ! [[ "$number" =~ ^[0-9]+$ ]] ||
       (( number < 1 || number > ${#VMS[@]} )); then
        error "Invalid VM."
        return 1
    fi

    local selected="${VMS[$((number-1))]}"

    "$action" "$selected"
}

main_menu() {
    while true; do
        header

        mapfile -t VMS < <(get_vms)

        echo "VMs: ${#VMS[@]}"
        echo

        if [[ ${#VMS[@]} -gt 0 ]]; then
            local i=1

            for vm in "${VMS[@]}"; do
                if is_running "$vm"; then
                    printf "  %2d) %-25s ${GREEN}[RUNNING]${RESET}\n" "$i" "$vm"
                else
                    printf "  %2d) %-25s ${YELLOW}[STOPPED]${RESET}\n" "$i" "$vm"
                fi

                ((i++))
            done

            echo
        fi

        echo "==================== MAIN MENU ===================="
        echo
        echo "  1) Create VM"
        echo "  2) Start VM"
        echo "  3) Stop VM"
        echo "  4) Restart VM"
        echo "  5) VM Info"
        echo "  6) SSH Details"
        echo "  7) Edit VM"
        echo "  8) Delete VM"
        echo "  9) Start ALL VMs"
        echo " 10) Install/Update Auto-start"
        echo " 11) KVM Status"
        echo "  0) Exit"
        echo

        input "Select option: "
        read -r choice

        case "$choice" in
            1)
                create_vm
                read -rp "Press Enter to continue..."
                ;;

            2)
                select_vm start_vm
                read -rp "Press Enter to continue..."
                ;;

            3)
                select_vm stop_vm
                read -rp "Press Enter to continue..."
                ;;

            4)
                select_vm restart_vm
                read -rp "Press Enter to continue..."
                ;;

            5)
                select_vm show_info
                read -rp "Press Enter to continue..."
                ;;

            6)
                select_vm show_ssh
                read -rp "Press Enter to continue..."
                ;;

            7)
                select_vm edit_vm
                read -rp "Press Enter to continue..."
                ;;

            8)
                select_vm delete_vm
                read -rp "Press Enter to continue..."
                ;;

            9)
                autostart_vms
                read -rp "Press Enter to continue..."
                ;;

            10)
                install_autostart_service
                read -rp "Press Enter to continue..."
                ;;

            11)
                echo
                check_kvm || true
                echo
                read -rp "Press Enter to continue..."
                ;;

            0)
                success "Goodbye from ZyroCloud KVM."
                exit 0
                ;;

            *)
                error "Invalid option."
                sleep 1
                ;;
        esac
    done
}

# ================================================================
# COMMAND-LINE MODE
# ================================================================

require_root
detect_os
install_dependencies

if [[ "${1:-}" == "--autostart" ]]; then
    autostart_vms
    exit 0
fi

check_kvm || true

install_autostart_service

main_menu
