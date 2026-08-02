#!/bin/bash
set -Eeuo pipefail

# ============================================================
# ZYROCLOUD AUTO UBUNTU KVM MANAGER
# Auto Install | Auto Resource Detect | Auto Start
# Username: root | Password: root
# ============================================================

VM_DIR="${VM_DIR:-$HOME/zyrocloud-vms}"
UBUNTU_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"

BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; }
input()   { echo -ne "${CYAN}[INPUT]${RESET} $*"; }

pause_screen() {
    echo
    read -rp "Press Enter to continue..."
}

# ------------------------------------------------------------
# ROOT CHECK
# ------------------------------------------------------------

if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# ------------------------------------------------------------
# AUTO INSTALL
# ------------------------------------------------------------

install_dependencies() {

    local missing=()

    command -v qemu-system-x86_64 >/dev/null 2>&1 || missing+=("qemu-system-x86")
    command -v qemu-img >/dev/null 2>&1 || missing+=("qemu-utils")
    command -v cloud-localds >/dev/null 2>&1 || missing+=("cloud-image-utils")
    command -v wget >/dev/null 2>&1 || missing+=("wget")
    command -v openssl >/dev/null 2>&1 || missing+=("openssl")

    if [[ ${#missing[@]} -eq 0 ]]; then
        success "KVM/QEMU dependencies already installed."
        return
    fi

    info "Missing packages: ${missing[*]}"
    info "Installing required packages..."

    if command -v apt-get >/dev/null 2>&1; then

        $SUDO apt-get update -y

        $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y \
            qemu-system-x86 \
            qemu-utils \
            cloud-image-utils \
            wget \
            curl \
            openssl \
            ca-certificates \
            genisoimage \
            net-tools \
            iproute2

    elif command -v dnf >/dev/null 2>&1; then

        $SUDO dnf install -y \
            qemu-system-x86 \
            qemu-img \
            cloud-utils \
            wget \
            curl \
            openssl \
            ca-certificates

    else
        error "Unsupported Linux distribution."
        exit 1
    fi

    success "Required packages installed."
}

# ------------------------------------------------------------
# KVM CHECK
# ------------------------------------------------------------

setup_kvm() {

    if [[ -e /dev/kvm ]]; then
        success "/dev/kvm detected."

        if [[ -r /dev/kvm && -w /dev/kvm ]]; then
            success "KVM is accessible."
        else
            warn "/dev/kvm exists but current user cannot access it."
            warn "QEMU will fall back to software acceleration."
        fi

        return
    fi

    warn "/dev/kvm not available."
    warn "VM will use software emulation. Performance will be lower."
}

# ------------------------------------------------------------
# CPU DETECTION
# ------------------------------------------------------------

detect_cpu() {

    local cpu_count

    cpu_count="$(nproc 2>/dev/null || echo 1)"

    # Keep at least 1 CPU for host.
    if (( cpu_count > 1 )); then
        VM_CPUS=$((cpu_count - 1))
    else
        VM_CPUS=1
    fi

    info "Host CPU threads : $cpu_count"
    info "VM CPU threads   : $VM_CPUS"
}

# ------------------------------------------------------------
# RAM DETECTION
# ------------------------------------------------------------

detect_ram() {

    local total_mb
    total_mb="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"

    # Reserve ~1GB for host when possible.
    if (( total_mb > 2048 )); then
        VM_RAM_MB=$((total_mb - 1024))
    else
        VM_RAM_MB=$((total_mb / 2))
    fi

    (( VM_RAM_MB < 512 )) && VM_RAM_MB=512

    info "Host RAM         : ${total_mb} MB"
    info "VM RAM            : ${VM_RAM_MB} MB"
}

# ------------------------------------------------------------
# DISK DETECTION
# ------------------------------------------------------------

detect_disk() {

    local available_mb

    available_mb="$(
        df -Pm "$VM_DIR" 2>/dev/null |
        awk 'NR==2 {print $4}'
    )"

    if [[ -z "$available_mb" ]]; then
        available_mb=2048
    fi

    # Keep 2GB free for host.
    if (( available_mb > 3072 )); then
        VM_DISK_MB=$((available_mb - 2048))
    else
        VM_DISK_MB=$((available_mb / 2))
    fi

    # Minimum 10GB
    if (( VM_DISK_MB < 10240 )); then
        VM_DISK_MB=10240
    fi

    VM_DISK_GB=$((VM_DISK_MB / 1024))

    info "Available disk    : ${available_mb} MB"
    info "VM disk           : ${VM_DISK_GB} GB"
}

# ------------------------------------------------------------
# RESOURCE DETECTION
# ------------------------------------------------------------

detect_resources() {

    echo
    info "Detecting host resources..."

    mkdir -p "$VM_DIR"

    detect_cpu
    detect_ram
    detect_disk

    echo
    success "Automatic resource allocation completed."
}

# ------------------------------------------------------------
# VM NAME
# ------------------------------------------------------------

ask_vm_name() {

    while true; do

        input "Enter VM name [zyrocloud]: "
        read -r VM_NAME

        VM_NAME="${VM_NAME:-zyrocloud}"

        if [[ ! "$VM_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            error "Invalid VM name."
            continue
        fi

        if [[ -e "$VM_DIR/$VM_NAME.conf" ]]; then
            error "VM '$VM_NAME' already exists."
            continue
        fi

        break
    done
}

# ------------------------------------------------------------
# PORT
# ------------------------------------------------------------

find_free_port() {

    local port=2222

    while ss -ltn 2>/dev/null | grep -q ":$port "; do
        ((port++))
    done

    SSH_PORT="$port"
}

# ------------------------------------------------------------
# DOWNLOAD UBUNTU
# ------------------------------------------------------------

download_ubuntu() {

    mkdir -p "$VM_DIR"

    IMG="$VM_DIR/$VM_NAME.qcow2"
    SEED="$VM_DIR/$VM_NAME-seed.iso"

    if [[ -f "$IMG" ]]; then
        success "Ubuntu image already exists."
        return
    fi

    info "Downloading Ubuntu 24.04 cloud image..."

    wget \
        --show-progress \
        --progress=bar:force \
        "$UBUNTU_URL" \
        -O "$IMG.tmp"

    mv "$IMG.tmp" "$IMG"

    success "Ubuntu image downloaded."
}

# ------------------------------------------------------------
# RESIZE DISK
# ------------------------------------------------------------

resize_disk() {

    info "Expanding Ubuntu disk to ${VM_DISK_GB}G..."

    qemu-img resize "$IMG" "${VM_DISK_GB}G" >/dev/null

    success "Disk size: ${VM_DISK_GB}G"
}

# ------------------------------------------------------------
# CLOUD INIT
# ------------------------------------------------------------

create_cloud_init() {

    local workdir

    workdir="$(mktemp -d)"

    cat > "$workdir/user-data" <<EOF
#cloud-config

hostname: $VM_NAME

manage_etc_hosts: true

ssh_pwauth: true

disable_root: false

users:
  - default

chpasswd:
  expire: false
  list:
    - root:root

ssh_authorized_keys: []

runcmd:
  - systemctl enable ssh || true
  - systemctl restart ssh || true
EOF

    cat > "$workdir/meta-data" <<EOF
instance-id: zyrocloud-$VM_NAME
local-hostname: $VM_NAME
EOF

    rm -f "$SEED"

    cloud-localds \
        "$SEED" \
        "$workdir/user-data" \
        "$workdir/meta-data"

    rm -rf "$workdir"

    chmod 600 "$SEED"

    success "Cloud-init configured."
}

# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------

save_config() {

    cat > "$VM_DIR/$VM_NAME.conf" <<EOF
VM_NAME="$VM_NAME"
IMG="$IMG"
SEED="$SEED"
RAM="$VM_RAM_MB"
CPUS="$VM_CPUS"
DISK="$VM_DISK_GB"
SSH_PORT="$SSH_PORT"
USERNAME="root"
PASSWORD="root"
CREATED="$(date '+%Y-%m-%d %H:%M:%S')"
EOF

    chmod 600 "$VM_DIR/$VM_NAME.conf"
}

# ------------------------------------------------------------
# KVM ARGUMENT
# ------------------------------------------------------------

get_acceleration() {

    if [[ -e /dev/kvm ]]; then
        echo "-enable-kvm"
    else
        echo ""
    fi
}

# ------------------------------------------------------------
# START VM
# ------------------------------------------------------------

start_vm() {

    local name="$1"

    if [[ ! -f "$VM_DIR/$name.conf" ]]; then
        error "VM '$name' not found."
        return 1
    fi

    # shellcheck disable=SC1090
    source "$VM_DIR/$name.conf"

    if pgrep -f "qemu-system-x86_64.*$IMG" >/dev/null 2>&1; then
        warn "VM '$name' is already running."
        return
    fi

    local accel
    accel="$(get_acceleration)"

    info "Starting VM: $name"

    info "RAM : ${RAM}MB"
    info "CPU : ${CPUS}"
    info "Disk: ${DISK}GB"
    info "SSH : $SSH_PORT"

    local log_file="$VM_DIR/$name.log"

    nohup qemu-system-x86_64 \
        $accel \
        -machine accel=kvm:tcg \
        -cpu host \
        -m "$RAM" \
        -smp "$CPUS" \
        -drive "file=$IMG,if=virtio,format=qcow2,cache=writeback,aio=native" \
        -drive "file=$SEED,if=virtio,format=raw,readonly=on" \
        -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22" \
        -device virtio-net-pci,netdev=net0 \
        -device virtio-balloon-pci \
        -object rng-random,filename=/dev/urandom,id=rng0 \
        -device virtio-rng-pci,rng=rng0 \
        -nographic \
        -serial "file:$VM_DIR/$name-console.log" \
        -monitor "unix:$VM_DIR/$name-monitor.sock,server,nowait" \
        > "$log_file" 2>&1 &

    echo $! > "$VM_DIR/$name.pid"

    sleep 3

    if kill -0 "$(cat "$VM_DIR/$name.pid")" 2>/dev/null; then
        success "VM '$name' started."
        echo
        echo "SSH:"
        echo "  ssh -p $SSH_PORT root@127.0.0.1"
        echo
        echo "Username: root"
        echo "Password: root"
        echo
        echo "Console log:"
        echo "  $VM_DIR/$name-console.log"
    else
        error "VM failed to start."
        echo
        tail -30 "$log_file" 2>/dev/null || true
        return 1
    fi
}

# ------------------------------------------------------------
# STOP VM
# ------------------------------------------------------------

stop_vm() {

    local name="$1"

    if [[ ! -f "$VM_DIR/$name.conf" ]]; then
        error "VM not found."
        return
    fi

    if [[ ! -f "$VM_DIR/$name.pid" ]]; then
        warn "VM is not running."
        return
    fi

    local pid
    pid="$(cat "$VM_DIR/$name.pid")"

    if ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$VM_DIR/$name.pid"
        warn "VM is already stopped."
        return
    fi

    info "Stopping $name..."

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

    rm -f "$VM_DIR/$name.pid"

    success "VM stopped."
}

# ------------------------------------------------------------
# STATUS
# ------------------------------------------------------------

vm_running() {

    local name="$1"

    [[ -f "$VM_DIR/$name.pid" ]] || return 1

    local pid
    pid="$(cat "$VM_DIR/$name.pid" 2>/dev/null || true)"

    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# ------------------------------------------------------------
# VM LIST
# ------------------------------------------------------------

get_vms() {

    find "$VM_DIR" \
        -maxdepth 1 \
        -type f \
        -name "*.conf" \
        -printf "%f\n" 2>/dev/null |
        sed 's/\.conf$//' |
        sort
}

# ------------------------------------------------------------
# VM INFO
# ------------------------------------------------------------

show_info() {

    local name="$1"

    if [[ ! -f "$VM_DIR/$name.conf" ]]; then
        error "VM not found."
        return
    fi

    # shellcheck disable=SC1090
    source "$VM_DIR/$name.conf"

    echo
    echo "=============================================="
    echo "             ZYROCLOUD VM INFO"
    echo "=============================================="
    echo "Name       : $VM_NAME"
    echo "OS         : Ubuntu 24.04"
    echo "Username   : root"
    echo "Password   : root"
    echo "RAM        : ${RAM} MB"
    echo "CPU        : $CPUS"
    echo "Disk       : ${DISK} GB"
    echo "SSH Port   : $SSH_PORT"
    echo "Status     : $(vm_running "$name" && echo Running || echo Stopped)"
    echo "Created    : $CREATED"
    echo "=============================================="
}

# ------------------------------------------------------------
# DELETE
# ------------------------------------------------------------

delete_vm() {

    local name="$1"

    if [[ ! -f "$VM_DIR/$name.conf" ]]; then
        error "VM not found."
        return
    fi

    if vm_running "$name"; then
        stop_vm "$name"
    fi

    echo
    warn "This will delete VM '$name' and its disk."

    read -rp "Type DELETE to confirm: " confirm

    if [[ "$confirm" != "DELETE" ]]; then
        warn "Cancelled."
        return
    fi

    rm -f \
        "$VM_DIR/$name.conf" \
        "$VM_DIR/$name.qcow2" \
        "$VM_DIR/$name-seed.iso" \
        "$VM_DIR/$name.pid" \
        "$VM_DIR/$name.log" \
        "$VM_DIR/$name-console.log" \
        "$VM_DIR/$name-monitor.sock"

    success "VM '$name' deleted."
}

# ------------------------------------------------------------
# CREATE VM
# ------------------------------------------------------------

create_vm() {

    echo
    echo "=============================================="
    echo "          CREATE ZYROCLOUD VM"
    echo "=============================================="

    ask_vm_name

    find_free_port
    detect_resources
    download_ubuntu
    resize_disk
    create_cloud_init
    save_config

    echo
    success "VM '$VM_NAME' created successfully."
    echo
    echo "Resources:"
    echo "  CPU : $VM_CPUS"
    echo "  RAM : ${VM_RAM_MB} MB"
    echo "  Disk: ${VM_DISK_GB} GB"
    echo
    echo "Login:"
    echo "  User: root"
    echo "  Pass: root"
    echo
    echo "SSH:"
    echo "  ssh -p $SSH_PORT root@127.0.0.1"
    echo

    read -rp "Start VM now? [Y/n]: " answer
    answer="${answer:-Y}"

    if [[ "$answer" =~ ^[Yy]$ ]]; then
        start_vm "$VM_NAME"
    fi
}

# ------------------------------------------------------------
# AUTO START EXISTING VMS
# ------------------------------------------------------------

auto_start_vms() {

    local found=0

    while IFS= read -r name; do

        [[ -z "$name" ]] && continue

        found=1

        if ! vm_running "$name"; then
            info "Auto-starting existing VM: $name"
            start_vm "$name" || warn "Could not start $name"
        fi

    done < <(get_vms)

    if (( found == 0 )); then
        info "No existing VMs found."
    fi
}

# ------------------------------------------------------------
# MAIN MENU
# ------------------------------------------------------------

main_menu() {

    while true; do

        clear

        echo "=============================================================="
        echo "              ZYROCLOUD KVM MANAGER"
        echo "=============================================================="
        echo
        echo "Ubuntu 24.04 | KVM | Auto RAM | Auto CPU | Auto Disk"
        echo

        local vms=()
        mapfile -t vms < <(get_vms)

        if (( ${#vms[@]} > 0 )); then

            echo "Existing VMs:"
            echo

            local i=1

            for vm in "${vms[@]}"; do

                local status="STOPPED"

                if vm_running "$vm"; then
                    status="RUNNING"
                fi

                printf "  %2d) %-25s [%s]\n" \
                    "$i" \
                    "$vm" \
                    "$status"

                ((i++))
            done

            echo
        else
            echo "No VMs created."
            echo
        fi

        echo "--------------------------------------------------------------"
        echo "1) Create Ubuntu VM"
        echo "2) Start VM"
        echo "3) Stop VM"
        echo "4) VM Info"
        echo "5) Delete VM"
        echo "6) Auto-start all VMs"
        echo "7) Host resources"
        echo "0) Exit"
        echo "--------------------------------------------------------------"
        echo

        input "Choose: "
        read -r choice

        case "$choice" in

            1)
                create_vm
                pause_screen
                ;;

            2)
                if (( ${#vms[@]} == 0 )); then
                    warn "No VMs available."
                    pause_screen
                    continue
                fi

                input "VM number: "
                read -r num

                if [[ "$num" =~ ^[0-9]+$ ]] &&
                   (( num >= 1 && num <= ${#vms[@]} )); then

                    start_vm "${vms[$((num-1))]}"

                else
                    error "Invalid VM number."
                fi

                pause_screen
                ;;

            3)
                if (( ${#vms[@]} == 0 )); then
                    warn "No VMs available."
                    pause_screen
                    continue
                fi

                input "VM number: "
                read -r num

                if [[ "$num" =~ ^[0-9]+$ ]] &&
                   (( num >= 1 && num <= ${#vms[@]} )); then

                    stop_vm "${vms[$((num-1))]}"

                else
                    error "Invalid VM number."
                fi

                pause_screen
                ;;

            4)
                if (( ${#vms[@]} == 0 )); then
                    warn "No VMs available."
                    pause_screen
                    continue
                fi

                input "VM number: "
                read -r num

                if [[ "$num" =~ ^[0-9]+$ ]] &&
                   (( num >= 1 && num <= ${#vms[@]} )); then

                    show_info "${vms[$((num-1))]}"

                else
                    error "Invalid VM number."
                fi

                pause_screen
                ;;

            5)
                if (( ${#vms[@]} == 0 )); then
                    warn "No VMs available."
                    pause_screen
                    continue
                fi

                input "VM number: "
                read -r num

                if [[ "$num" =~ ^[0-9]+$ ]] &&
                   (( num >= 1 && num <= ${#vms[@]} )); then

                    delete_vm "${vms[$((num-1))]}"

                else
                    error "Invalid VM number."
                fi

                pause_screen
                ;;

            6)
                auto_start_vms
                pause_screen
                ;;

            7)
                detect_resources
                pause_screen
                ;;

            0)
                success "Goodbye."
                exit 0
                ;;

            *)
                error "Invalid option."
                sleep 1
                ;;

        esac
    done
}

# ------------------------------------------------------------
# INITIAL SETUP
# ------------------------------------------------------------

mkdir -p "$VM_DIR"

install_dependencies
setup_kvm

# ------------------------------------------------------------
# OPTIONAL AUTO START
# ------------------------------------------------------------

if [[ "${AUTO_START_VMS:-yes}" == "yes" ]]; then
    auto_start_vms
fi

main_menu
