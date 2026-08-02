#!/bin/bash
set -Eeuo pipefail

# ================================================================
#                     ZYROCLOUD KVM
#                  Multi VM Manager v2
# ================================================================

APP_NAME="ZyroCloud KVM"
BASE_DIR="/var/lib/zyrocloud-kvm"
VM_DIR="$BASE_DIR/vms"
LOG_DIR="$BASE_DIR/logs"
RUN_DIR="$BASE_DIR/run"

SERVICE_NAME="zyrocloud-kvm-autostart.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
AUTOSTART_CMD="/usr/local/bin/zyrocloud-kvm-autostart"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; }
input()   { echo -en "${CYAN}[INPUT]${RESET} $*"; }

header() {
    clear 2>/dev/null || true

    cat <<'EOF'
========================================================================

  _    _  ____  _____ _____ _   _  _____ ____   ______     ________
 | |  | |/ __ \|  __ \_   _| \ | |/ ____|  _ \ / __ \ \   / /___  /
 | |__| | |  | | |__) || | |  \| | |  __| |_) | |  | \ \_/ /   / /
 |  __  | |  | |  ___/ | | |   \ | | |_ |  _ <| |  | |\   /   / /
 | |  | | |__| | |    _| |_| |\  | |__| | |_) | |__| | | |   / /__
 |_|  |_|\____/|_|   |_____|_| \_|\_____|____/ \____/  |_|  /_____|

                         ZYROCLOUD KVM
                      VIRTUAL MACHINE MANAGER

========================================================================
EOF
    echo
}

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "Run this script as root."
        exit 1
    fi
}

prepare_dirs() {
    mkdir -p "$VM_DIR" "$LOG_DIR" "$RUN_DIR"
    chmod 700 "$BASE_DIR" "$VM_DIR" "$RUN_DIR"
}

# ================================================================
# SYSTEMD DETECTION
# ================================================================

systemd_available() {
    command -v systemctl >/dev/null 2>&1 &&
    [[ "$(ps -p 1 -o comm= 2>/dev/null || true)" == "systemd" ]]
}

# ================================================================
# KVM DETECTION
# ================================================================

KVM_MODE="tcg"

detect_kvm() {
    if [[ -e /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
        KVM_MODE="kvm"
        success "Hardware KVM detected."
        info "Acceleration: KVM"
    else
        KVM_MODE="tcg"
        warn "/dev/kvm is not available."
        warn "Using QEMU TCG software emulation."
    fi
}

# ================================================================
# DEPENDENCIES
# ================================================================

install_dependencies() {
    info "Checking QEMU/KVM dependencies..."

    local missing=()

    command -v qemu-system-x86_64 >/dev/null 2>&1 || \
        missing+=("qemu-system-x86")

    command -v qemu-img >/dev/null 2>&1 || \
        missing+=("qemu-utils")

    command -v cloud-localds >/dev/null 2>&1 || \
        missing+=("cloud-image-utils")

    command -v wget >/dev/null 2>&1 || \
        missing+=("wget")

    command -v openssl >/dev/null 2>&1 || \
        missing+=("openssl")

    if [[ "${#missing[@]}" -eq 0 ]]; then
        success "QEMU dependencies are already installed."
        return
    fi

    info "Missing packages: ${missing[*]}"

    if ! command -v apt-get >/dev/null 2>&1; then
        error "APT package manager not found."
        error "Install QEMU manually for this operating system."
        exit 1
    fi

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

    success "Dependencies installed."
}

# ================================================================
# OS IMAGES
# ================================================================

declare -A OS_OPTIONS

OS_OPTIONS["Ubuntu 24.04"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu"

OS_OPTIONS["Ubuntu 22.04"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu"

OS_OPTIONS["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian"

OS_OPTIONS["Debian 11"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian"

OS_OPTIONS["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|alma"

OS_OPTIONS["Rocky Linux 9"]="rocky|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky"

# ================================================================
# VM FUNCTIONS
# ================================================================

get_vms() {
    find "$VM_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type f \
        -name "*.conf" \
        -printf "%f\n" 2>/dev/null |
        sed 's/\.conf$//' |
        sort
}

vm_exists() {
    [[ -f "$VM_DIR/$1.conf" ]]
}

load_vm() {
    local name="$1"
    local config="$VM_DIR/$name.conf"

    if [[ ! -f "$config" ]]; then
        error "VM '$name' not found."
        return 1
    fi

    unset \
        VM_NAME \
        OS_TYPE \
        CODENAME \
        IMG_URL \
        HOSTNAME \
        USERNAME \
        PASSWORD \
        DISK_SIZE \
        MEMORY \
        CPUS \
        SSH_PORT \
        GUI_MODE \
        IMG_FILE \
        SEED_FILE \
        CREATED \
        AUTOSTART

    # shellcheck disable=SC1090
    source "$config"
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

    chmod 600 "$VM_DIR/$VM_NAME.conf"
}

pid_file() {
    echo "$RUN_DIR/$1.pid"
}

log_file() {
    echo "$LOG_DIR/$1.log"
}

monitor_file() {
    echo "$RUN_DIR/$1-monitor.sock"
}

is_running() {
    local name="$1"
    local pidfile
    pidfile="$(pid_file "$name")"

    [[ -f "$pidfile" ]] || return 1

    local pid
    pid="$(cat "$pidfile" 2>/dev/null || true)"

    [[ "$pid" =~ ^[0-9]+$ ]] || return 1

    kill -0 "$pid" 2>/dev/null
}

valid_name() {
    [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]]
}

valid_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

port_available() {
    local port="$1"

    ! ss -lnt 2>/dev/null |
        awk '{print $4}' |
        grep -Eq "[:.]${port}$"
}

find_free_port() {
    local port=2222

    while ! port_available "$port"; do
        ((port++))
    done

    echo "$port"
}

# ================================================================
# CLOUD INIT
# ================================================================

create_cloud_init() {
    local user_data="$VM_DIR/$VM_NAME-user-data"
    local meta_data="$VM_DIR/$VM_NAME-meta-data"

    local password_hash
    password_hash="$(openssl passwd -6 "$PASSWORD")"

    cat > "$user_data" <<EOF
#cloud-config

hostname: $HOSTNAME

manage_etc_hosts: true

ssh_pwauth: true

disable_root: false

users:
  - name: $USERNAME
    groups:
      - sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $password_hash

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

    cloud-localds \
        "$SEED_FILE" \
        "$user_data" \
        "$meta_data"

    rm -f "$user_data" "$meta_data"
}

# ================================================================
# IMAGE
# ================================================================

download_image() {
    if [[ -f "$IMG_FILE" ]]; then
        info "Image already exists."
        return
    fi

    info "Downloading OS image..."
    echo "$IMG_URL"

    local tmp="$IMG_FILE.download"

    rm -f "$tmp"

    wget \
        --tries=3 \
        --timeout=30 \
        --progress=bar:force \
        "$IMG_URL" \
        -O "$tmp"

    mv "$tmp" "$IMG_FILE"

    success "Image downloaded."
}

prepare_disk() {
    info "Resizing disk to $DISK_SIZE..."

    qemu-img resize "$IMG_FILE" "$DISK_SIZE"

    success "Disk ready."
}

# ================================================================
# CREATE VM
# ================================================================

create_vm() {
    header

    echo "==================== CREATE VM ===================="
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

        error "Invalid selection."
    done

    local selected="${names[$choice]}"

    IFS='|' read -r \
        OS_TYPE \
        CODENAME \
        IMG_URL \
        DEFAULT_USERNAME <<< "${OS_OPTIONS[$selected]}"

    echo

    while true; do
        input "VM name: "
        read -r VM_NAME

        VM_NAME="${VM_NAME:-${CODENAME}-vm}"

        if ! valid_name "$VM_NAME"; then
            error "Invalid VM name."
            continue
        fi

        if vm_exists "$VM_NAME"; then
            error "VM already exists."
            continue
        fi

        break
    done

    input "Hostname [$VM_NAME]: "
    read -r HOSTNAME
    HOSTNAME="${HOSTNAME:-$VM_NAME}"

    input "Username [$DEFAULT_USERNAME]: "
    read -r USERNAME
    USERNAME="${USERNAME:-$DEFAULT_USERNAME}"

    while true; do
        input "Password: "
        read -rs PASSWORD
        echo

        [[ -n "$PASSWORD" ]] && break

        error "Password cannot be empty."
    done

    input "Disk size [20G]: "
    read -r DISK_SIZE
    DISK_SIZE="${DISK_SIZE:-20G}"

    if ! [[ "$DISK_SIZE" =~ ^[0-9]+[GgMm]$ ]]; then
        error "Invalid disk size."
        return 1
    fi

    input "RAM MB [2048]: "
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

    info "Selected SSH port: $SSH_PORT"

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
    info "Preparing ZyroCloud VM..."

    download_image
    prepare_disk
    create_cloud_init
    save_vm

    success "VM '$VM_NAME' created successfully."

    echo
    info "Starting VM automatically..."

    start_vm "$VM_NAME"
}

# ================================================================
# QEMU COMMAND
# ================================================================

build_qemu_command() {
    local name="$1"

    load_vm "$name"

    local accel
    local cpu

    if [[ "$KVM_MODE" == "kvm" ]]; then
        accel="kvm"
        cpu="host"
    else
        accel="tcg"
        cpu="max"
    fi

    QEMU_CMD=(
        qemu-system-x86_64

        -name "zyrocloud-$VM_NAME"

        -machine "q35,accel=$accel"

        -cpu "$cpu"

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

        -pidfile "$(pid_file "$VM_NAME")"

        -daemonize
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

# ================================================================
# START
# ================================================================

start_vm() {
    local name="$1"

    load_vm "$name"

    if is_running "$name"; then
        warn "VM '$name' is already running."
        show_ssh "$name"
        return
    fi

    if [[ ! -f "$IMG_FILE" ]]; then
        error "VM disk not found."
        return 1
    fi

    if [[ ! -f "$SEED_FILE" ]]; then
        warn "Cloud-init seed missing."
        create_cloud_init
    fi

    if ! port_available "$SSH_PORT"; then
        error "SSH port $SSH_PORT is already in use."
        return 1
    fi

    detect_kvm

    info "Starting VM: $name"
    info "Acceleration: $KVM_MODE"

    build_qemu_command "$name"

    "${QEMU_CMD[@]}" \
        >> "$(log_file "$name")" 2>&1

    sleep 2

    if is_running "$name"; then
        success "VM '$name' started."
        show_ssh "$name"
    else
        error "VM failed to start."
        echo
        tail -30 "$(log_file "$name")" 2>/dev/null || true
        return 1
    fi
}

# ================================================================
# STOP
# ================================================================

stop_vm() {
    local name="$1"

    load_vm "$name"

    if ! is_running "$name"; then
        info "VM '$name' is already stopped."
        return
    fi

    local pid
    pid="$(cat "$(pid_file "$name")")"

    info "Stopping VM '$name'..."

    kill "$pid" 2>/dev/null || true

    for _ in {1..10}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi

        sleep 1
    done

    if kill -0 "$pid" 2>/dev/null; then
        warn "Force stopping VM..."
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$(pid_file "$name")"

    success "VM '$name' stopped."
}

restart_vm() {
    local name="$1"

    stop_vm "$name"

    sleep 1

    start_vm "$name"
}

# ================================================================
# SSH
# ================================================================

show_ssh() {
    local name="$1"

    load_vm "$name"

    local ip
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"

    echo
    echo "================================================================"
    echo "                    ZYROCLOUD SSH DETAILS"
    echo "================================================================"
    echo
    echo "VM         : $VM_NAME"
    echo "Hostname   : $HOSTNAME"
    echo "Username   : $USERNAME"
    echo "Password   : $PASSWORD"
    echo "SSH Port   : $SSH_PORT"
    echo
    echo "SSH Command:"
    echo
    echo "ssh -p $SSH_PORT $USERNAME@$ip"
    echo
    echo "================================================================"
}

# ================================================================
# VM INFO
# ================================================================

show_info() {
    local name="$1"

    load_vm "$name"

    echo
    echo "================================================================"
    echo "                         VM INFORMATION"
    echo "================================================================"
    echo
    echo "Name        : $VM_NAME"
    echo "OS          : $OS_TYPE"
    echo "Version     : $CODENAME"
    echo "Hostname    : $HOSTNAME"
    echo "Username    : $USERNAME"
    echo "SSH Port    : $SSH_PORT"
    echo "RAM         : $MEMORY MB"
    echo "CPU         : $CPUS"
    echo "Disk        : $DISK_SIZE"
    echo "Autostart   : $AUTOSTART"
    echo "Acceleration: $KVM_MODE"
    echo "Status      : $(is_running "$name" && echo RUNNING || echo STOPPED)"
    echo "Created     : $CREATED"
    echo
    echo "Disk:"
    echo "$IMG_FILE"
    echo
    echo "================================================================"
}

# ================================================================
# DELETE
# ================================================================

delete_vm() {
    local name="$1"

    load_vm "$name"

    warn "This will permanently delete '$name'."

    input "Type DELETE to continue: "
    read -r confirm

    if [[ "$confirm" != "DELETE" ]]; then
        info "Cancelled."
        return
    fi

    if is_running "$name"; then
        stop_vm "$name"
    fi

    rm -f \
        "$VM_DIR/$name.conf" \
        "$VM_DIR/$name.qcow2" \
        "$VM_DIR/$name-seed.iso" \
        "$RUN_DIR/$name.pid" \
        "$LOG_DIR/$name.log"

    success "VM '$name' deleted."
}

# ================================================================
# AUTO START
# ================================================================

autostart_vms() {
    info "Starting ZyroCloud VMs..."

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue

        if load_vm "$name"; then
            if [[ "${AUTOSTART:-true}" == true ]]; then
                if is_running "$name"; then
                    info "$name already running."
                else
                    start_vm "$name" || \
                        warn "Could not start $name"
                fi
            fi
        fi

    done < <(get_vms)

    success "VM auto-start completed."
}

# ================================================================
# AUTOSTART INSTALL
# ================================================================

install_autostart() {
    info "Configuring ZyroCloud auto-start..."

    if systemd_available; then

        info "systemd detected."

        cat > "$SERVICE_FILE" <<EOF
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

        chmod 644 "$SERVICE_FILE"

        systemctl daemon-reload
        systemctl enable "$SERVICE_NAME"

        success "systemd auto-start enabled."

    else

        warn "systemd is not available in this environment."
        warn "Skipping systemd configuration."

        cat > "$AUTOSTART_CMD" <<EOF
#!/bin/bash
exec "$0" --autostart
EOF

        chmod +x "$AUTOSTART_CMD"

        success "Non-systemd auto-start command created:"
        echo
        echo "  $AUTOSTART_CMD"
        echo
    fi
}

# ================================================================
# EDIT
# ================================================================

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
            input "RAM MB [$MEMORY]: "
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
            input "CPU [$CPUS]: "
            read -r value
            value="${value:-$CPUS}"

            if valid_number "$value"; then
                CPUS="$value"
                save_vm
                success "CPU updated."
            else
                error "Invalid CPU."
            fi
            ;;

        3)
            input "SSH port [$SSH_PORT]: "
            read -r value
            value="${value:-$SSH_PORT}"

            if [[ "$value" == "$SSH_PORT" ]] || port_available "$value"; then
                SSH_PORT="$value"
                save_vm
                success "SSH port updated."
            else
                error "Port already in use."
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
                success "Password updated."
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

# ================================================================
# SELECT VM
# ================================================================

select_vm() {
    local action="$1"

    mapfile -t VMS < <(get_vms)

    if [[ "${#VMS[@]}" -eq 0 ]]; then
        warn "No VMs found."
        return
    fi

    echo

    local i=1

    for vm in "${VMS[@]}"; do

        if is_running "$vm"; then
            printf " %2d) %-25s ${GREEN}[RUNNING]${RESET}\n" \
                "$i" "$vm"
        else
            printf " %2d) %-25s ${YELLOW}[STOPPED]${RESET}\n" \
                "$i" "$vm"
        fi

        ((i++))
    done

    echo

    input "Select VM: "
    read -r number

    if ! [[ "$number" =~ ^[0-9]+$ ]] ||
       (( number < 1 || number > ${#VMS[@]} )); then
        error "Invalid VM."
        return
    fi

    "$action" "${VMS[$((number-1))]}"
}

# ================================================================
# MAIN MENU
# ================================================================

main_menu() {

    while true; do

        header

        detect_kvm

        mapfile -t VMS < <(get_vms)

        echo
        echo "VM Count: ${#VMS[@]}"
        echo "Acceleration: $KVM_MODE"
        echo

        if [[ "${#VMS[@]}" -gt 0 ]]; then

            local i=1

            for vm in "${VMS[@]}"; do

                if is_running "$vm"; then
                    printf " %2d) %-25s ${GREEN}[RUNNING]${RESET}\n" \
                        "$i" "$vm"
                else
                    printf " %2d) %-25s ${YELLOW}[STOPPED]${RESET}\n" \
                        "$i" "$vm"
                fi

                ((i++))
            done

            echo
        fi

        echo "==================== ZYROCLOUD ===================="
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
        echo " 10) Configure Auto-start"
        echo " 11) KVM Status"
        echo " 12) Show VM Logs"
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
                install_autostart
                read -rp "Press Enter to continue..."
                ;;

            11)
                echo
                detect_kvm
                echo
                read -rp "Press Enter to continue..."
                ;;

            12)
                select_vm show_logs
                read -rp "Press Enter to continue..."
                ;;

            0)
                success "Goodbye from ZyroCloud."
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
# LOG VIEWER
# ================================================================

show_logs() {
    local name="$1"

    echo
    echo "==================== $name LOG ===================="
    echo

    if [[ -f "$(log_file "$name")" ]]; then
        tail -100 "$(log_file "$name")"
    else
        warn "No log available."
    fi
}

# ================================================================
# STARTUP
# ================================================================

require_root
prepare_dirs
install_dependencies
detect_kvm

if [[ "${1:-}" == "--autostart" ]]; then
    autostart_vms
    exit 0
fi

install_autostart

main_menu
