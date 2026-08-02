#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
#                 ZYROCLOUD INSTALLER
#                      KVM MAKER
#                  Optimized / Fast v2
# ============================================================

# ---------------- COLORS ----------------
P='\033[1;35m'
LP='\033[0;95m'
C='\033[1;36m'
G='\033[1;32m'
Y='\033[1;33m'
R='\033[1;31m'
W='\033[1;37m'
D='\033[0;90m'
N='\033[0m'

# ---------------- CONFIG ----------------
VM_DIR="${VM_DIR:-$HOME/zyrocloud-vms}"
STATE_DIR="$VM_DIR/.state"
mkdir -p "$VM_DIR" "$STATE_DIR"

# ---------------- BASIC FUNCTIONS ----------------
pause() {
    read -rp "$(echo -e "${D}Press Enter to continue...${N}")"
}

info() {
    echo -e "${C}[INFO]${N} $*"
}

success() {
    echo -e "${G}[SUCCESS]${N} $*"
}

warn() {
    echo -e "${Y}[WARN]${N} $*"
}

error() {
    echo -e "${R}[ERROR]${N} $*"
}

die() {
    error "$*"
    exit 1
}

header() {
    clear
    echo -e "${P}"
    cat <<'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║                    ZYROCLOUD INSTALLER                              ║
║                         KVM MAKER                                    ║
║                                                                      ║
║                    FAST • CLEAN • KVM                                ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${N}"
}

fast_anim() {
    local text="$1"
    printf "${P}%s${N}" "$text"
    for _ in 1 2 3; do
        printf "."
        sleep 0.08
    done
    printf "\r\033[K"
}

# ---------------- ROOT CHECK ----------------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        warn "Running without root."
        warn "KVM installation may require sudo."
    fi
}

# ---------------- PACKAGE MANAGER ----------------
pkg_install() {

    if command -v apt-get >/dev/null 2>&1; then

        export DEBIAN_FRONTEND=noninteractive

        if [[ ! -f "$STATE_DIR/apt-updated" ]]; then
            info "Updating package lists..."
            sudo apt-get update -y
            touch "$STATE_DIR/apt-updated"
        fi

        sudo apt-get install -y \
            qemu-system-x86 \
            qemu-utils \
            cloud-image-utils \
            wget \
            curl \
            openssl \
            iproute2 \
            procps \
            ca-certificates \
            cpu-checker

    elif command -v dnf >/dev/null 2>&1; then

        sudo dnf install -y \
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

        sudo yum install -y \
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
        die "Unsupported Linux distribution."
    fi
}

# ---------------- KVM CHECK ----------------
check_kvm() {

    if [[ -e /dev/kvm ]]; then

        KVM_ACCEL="kvm"
        success "KVM acceleration detected."

    else

        KVM_ACCEL="tcg"
        warn "/dev/kvm not available."
        warn "Using QEMU software acceleration."
        warn "For best performance, run on a VPS/host with nested KVM."

    fi
}

# ---------------- INSTALL KVM ----------------
install_kvm() {

    header

    info "Installing KVM/QEMU..."
    echo

    pkg_install

    echo

    local required=(
        qemu-system-x86_64
        qemu-img
        wget
        cloud-localds
    )

    local missing=()

    for cmd in "${required[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if (( ${#missing[@]} )); then
        error "Missing commands: ${missing[*]}"
        return 1
    fi

    check_kvm

    echo
    success "KVM installation completed."
    echo

    info "Opening KVM Maker..."
    sleep 0.5

    kvm_manager
}

# ============================================================
#                    VM CONFIGURATION
# ============================================================

declare -A OS_OPTIONS=(

["Ubuntu 24.04"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu"

["Ubuntu 22.04"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu"

["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian"

["Debian 11"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian"

["Rocky Linux 9"]="rocky|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky"

["AlmaLinux 9"]="alma|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|alma9|alma"

["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos"
)

# ---------------- VM LIST ----------------
get_vms() {
    find "$VM_DIR" -maxdepth 1 -type f -name "*.conf" \
        -printf "%f\n" 2>/dev/null |
        sed 's/\.conf$//' |
        sort
}

# ---------------- LOAD CONFIG ----------------
load_vm() {

    local name="$1"
    local file="$VM_DIR/$name.conf"

    [[ -f "$file" ]] || return 1

    unset VM_NAME OS_TYPE CODENAME IMG_URL
    unset HOSTNAME USERNAME PASSWORD
    unset DISK_SIZE MEMORY CPUS SSH_PORT
    unset GUI_MODE PORT_FORWARDS
    unset IMG_FILE SEED_FILE CREATED

    # shellcheck disable=SC1090
    source "$file"

    return 0
}

# ---------------- SAVE CONFIG ----------------
save_vm() {

    local file="$VM_DIR/$VM_NAME.conf"

    cat > "$file" <<EOF
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
PORT_FORWARDS=$(printf '%q' "$PORT_FORWARDS")
IMG_FILE=$(printf '%q' "$IMG_FILE")
SEED_FILE=$(printf '%q' "$SEED_FILE")
CREATED=$(printf '%q' "$CREATED")
EOF
}

# ---------------- PORT CHECK ----------------
port_free() {

    local port="$1"

    if ss -lnt 2>/dev/null |
        awk '{print $4}' |
        grep -Eq "[:.]${port}$"; then

        return 1
    fi

    return 0
}

# ---------------- VM NAME VALIDATION ----------------
valid_name() {
    [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]]
}

# ---------------- IMAGE SETUP ----------------
setup_image() {

    mkdir -p "$VM_DIR"

    info "Preparing disk image..."

    if [[ ! -f "$IMG_FILE" ]]; then

        info "Downloading OS image..."
        wget -q --show-progress \
            "$IMG_URL" \
            -O "$IMG_FILE.tmp"

        mv "$IMG_FILE.tmp" "$IMG_FILE"

    else
        info "OS image already exists."
    fi

    # Convert downloaded image to qcow2 if required
    local format

    format="$(qemu-img info "$IMG_FILE" 2>/dev/null |
        awk -F': ' '/file format/ {print $2}' || true)"

    if [[ "$format" != "qcow2" ]]; then

        info "Converting image to QCOW2..."

        qemu-img convert \
            -p \
            -f "$format" \
            -O qcow2 \
            "$IMG_FILE" \
            "$IMG_FILE.converted"

        mv "$IMG_FILE.converted" "$IMG_FILE"
    fi

    info "Setting disk size: $DISK_SIZE"

    qemu-img resize "$IMG_FILE" "$DISK_SIZE" >/dev/null 2>&1 || true

    # Cloud-init
    local hash
    hash="$(openssl passwd -6 "$PASSWORD")"

    cat > "$VM_DIR/.user-data" <<EOF
#cloud-config

hostname: $HOSTNAME
manage_etc_hosts: true

users:
  - default
  - name: $USERNAME
    groups: sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $hash

ssh_pwauth: true
disable_root: false

chpasswd:
  expire: false

runcmd:
  - systemctl enable ssh || true
  - systemctl restart ssh || true
EOF

    cat > "$VM_DIR/.meta-data" <<EOF
instance-id: $VM_NAME
local-hostname: $HOSTNAME
EOF

    cloud-localds \
        "$SEED_FILE" \
        "$VM_DIR/.user-data" \
        "$VM_DIR/.meta-data"

    rm -f \
        "$VM_DIR/.user-data" \
        "$VM_DIR/.meta-data"

    success "VM image prepared."
}

# ============================================================
#                    CREATE VM
# ============================================================

create_vm() {

    header

    echo -e "${P}Select Operating System:${N}"
    echo

    local names=()
    local i=1

    for name in "${!OS_OPTIONS[@]}"; do
        names[$i]="$name"
        echo -e "  ${P}$i)${N} $name"
        ((i++))
    done

    echo

    local choice

    while true; do

        read -rp "$(echo -e "${LP}OS: ${N}")" choice

        if [[ "$choice" =~ ^[0-9]+$ ]] &&
            (( choice >= 1 && choice < i )); then
            break
        fi

        error "Invalid selection."
    done

    local os="${names[$choice]}"

    IFS='|' read -r \
        OS_TYPE \
        CODENAME \
        IMG_URL \
        DEFAULT_HOSTNAME \
        DEFAULT_USERNAME \
        <<< "${OS_OPTIONS[$os]}"

    echo

    # Name
    while true; do

        read -rp "$(echo -e "${LP}VM Name [$DEFAULT_HOSTNAME]: ${N}")" VM_NAME
        VM_NAME="${VM_NAME:-$DEFAULT_HOSTNAME}"

        if ! valid_name "$VM_NAME"; then
            error "Invalid VM name."
            continue
        fi

        if [[ -f "$VM_DIR/$VM_NAME.conf" ]]; then
            error "VM already exists."
            continue
        fi

        break
    done

    read -rp "$(echo -e "${LP}Hostname [$VM_NAME]: ${N}")" HOSTNAME
    HOSTNAME="${HOSTNAME:-$VM_NAME}"

    read -rp "$(echo -e "${LP}Username [$DEFAULT_USERNAME]: ${N}")" USERNAME
    USERNAME="${USERNAME:-$DEFAULT_USERNAME}"

    read -rsp "$(echo -e "${LP}Password: ${N}")" PASSWORD
    echo

    if [[ -z "$PASSWORD" ]]; then
        PASSWORD="$DEFAULT_USERNAME"
    fi

    read -rp "$(echo -e "${LP}Disk size [20G]: ${N}")" DISK_SIZE
    DISK_SIZE="${DISK_SIZE:-20G}"

    read -rp "$(echo -e "${LP}RAM MB [2048]: ${N}")" MEMORY
    MEMORY="${MEMORY:-2048}"

    read -rp "$(echo -e "${LP}CPU cores [2]: ${N}")" CPUS
    CPUS="${CPUS:-2}"

    while true; do

        read -rp "$(echo -e "${LP}SSH port [2222]: ${N}")" SSH_PORT
        SSH_PORT="${SSH_PORT:-2222}"

        if port_free "$SSH_PORT"; then
            break
        fi

        error "Port $SSH_PORT is already in use."
    done

    # VPS default = no GUI
    GUI_MODE=false

    read -rp "$(echo -e "${LP}Enable GUI? (y/N): ${N}")" gui

    if [[ "$gui" =~ ^[Yy]$ ]]; then
        GUI_MODE=true
    fi

    read -rp "$(echo -e "${LP}Extra ports (host:guest,host:guest): ${N}")" PORT_FORWARDS

    IMG_FILE="$VM_DIR/$VM_NAME.qcow2"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date '+%Y-%m-%d %H:%M:%S')"

    echo

    setup_image
    save_vm

    success "VM '$VM_NAME' created successfully."
}

# ============================================================
#                    VM PID MANAGEMENT
# ============================================================

pid_file() {
    echo "$STATE_DIR/$1.pid"
}

get_pid() {

    local vm="$1"
    local file
    file="$(pid_file "$vm")"

    [[ -f "$file" ]] || return 1

    local pid
    pid="$(cat "$file" 2>/dev/null || true)"

    [[ -n "$pid" ]] || return 1

    if kill -0 "$pid" 2>/dev/null; then
        echo "$pid"
        return 0
    fi

    rm -f "$file"
    return 1
}

vm_running() {
    get_pid "$1" >/dev/null 2>&1
}

# ============================================================
#                    BUILD QEMU COMMAND
# ============================================================

build_qemu() {

    local vm="$1"

    load_vm "$vm" || return 1

    QEMU_CMD=(

        qemu-system-x86_64

        -name "$VM_NAME"

        -machine "type=q35,accel=$KVM_ACCEL"

        -cpu host

        -enable-kvm

        -m "$MEMORY"

        -smp "$CPUS"

        -drive "file=$IMG_FILE,if=virtio,format=qcow2,cache=none,aio=native"

        -drive "file=$SEED_FILE,if=virtio,format=raw,readonly=on"

        -boot order=c

        -nodefaults

        -netdev "user,id=net0,hostfwd=tcp::$SSH_PORT-:22"

        -device "virtio-net-pci,netdev=net0"

        -device virtio-balloon-pci

        -object rng-random,filename=/dev/urandom,id=rng0

        -device virtio-rng-pci,rng=rng0

        -monitor none
    )

    # If KVM is unavailable, remove -enable-kvm
    if [[ "$KVM_ACCEL" != "kvm" ]]; then

        local new_cmd=()

        for arg in "${QEMU_CMD[@]}"; do
            [[ "$arg" == "-enable-kvm" ]] && continue
            new_cmd+=("$arg")
        done

        QEMU_CMD=("${new_cmd[@]}")
    fi

    # Extra ports
    if [[ -n "${PORT_FORWARDS:-}" ]]; then

        local index=1

        IFS=',' read -ra forwards <<< "$PORT_FORWARDS"

        for f in "${forwards[@]}"; do

            [[ "$f" == *:* ]] || continue

            local hp="${f%%:*}"
            local gp="${f##*:}"

            if ! port_free "$hp"; then
                warn "Host port $hp already used. Skipping."
                continue
            fi

            QEMU_CMD+=(
                -netdev "user,id=net$index,hostfwd=tcp::$hp-:$gp"
            )

            # One virtio NIC is enough; extra netdev isn't needed.
            ((index++))
        done
    fi

    if [[ "$GUI_MODE" == true ]]; then

        QEMU_CMD+=(
            -vga virtio
        )

    else

        QEMU_CMD+=(
            -nographic
            -serial mon:stdio
        )

    fi
}

# ============================================================
#                    START VM
# ============================================================

start_vm() {

    local vm="$1"

    load_vm "$vm" || return 1

    if vm_running "$vm"; then
        warn "VM '$vm' is already running."
        return 0
    fi

    [[ -f "$IMG_FILE" ]] ||
        die "Disk image missing."

    [[ -f "$SEED_FILE" ]] ||
        setup_image

    build_qemu "$vm"

    local pid
    local pf
    pf="$(pid_file "$vm")"

    echo
    echo -e "${G}VM:${N}       $VM_NAME"
    echo -e "${G}SSH:${N}      ssh -p $SSH_PORT $USERNAME@localhost"
    echo -e "${G}RAM:${N}      ${MEMORY}MB"
    echo -e "${G}CPU:${N}      $CPUS"
    echo -e "${G}KVM:${N}      $KVM_ACCEL"
    echo

    info "Starting VM..."

    # Headless VM runs in background.
    if [[ "$GUI_MODE" == false ]]; then

        nohup "${QEMU_CMD[@]}" \
            > "$STATE_DIR/$VM_NAME.log" 2>&1 &

        pid=$!

        echo "$pid" > "$pf"

        sleep 1

        if kill -0 "$pid" 2>/dev/null; then
            success "VM started. PID: $pid"
        else
            rm -f "$pf"
            error "VM failed to start."
            tail -n 20 "$STATE_DIR/$VM_NAME.log" 2>/dev/null || true
            return 1
        fi

    else

        "${QEMU_CMD[@]}"
    fi
}

# ============================================================
#                    STOP VM
# ============================================================

stop_vm() {

    local vm="$1"

    local pid

    pid="$(get_pid "$vm" 2>/dev/null || true)"

    if [[ -z "$pid" ]]; then
        warn "VM '$vm' is not running."
        return
    fi

    info "Stopping VM..."

    kill -TERM "$pid" 2>/dev/null || true

    for _ in {1..10}; do

        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi

        sleep 0.3
    done

    if kill -0 "$pid" 2>/dev/null; then
        warn "Forcing VM shutdown..."
        kill -KILL "$pid" 2>/dev/null || true
    fi

    rm -f "$(pid_file "$vm")"

    success "VM stopped."
}

# ============================================================
#                    VM INFO
# ============================================================

vm_info() {

    local vm="$1"

    load_vm "$vm" || return 1

    local status="Stopped"

    vm_running "$vm" && status="Running"

    echo
    echo -e "${P}════════════════ VM INFO ════════════════${N}"

    echo -e "${C}Name:${N}       $VM_NAME"
    echo -e "${C}OS:${N}         $OS_TYPE $CODENAME"
    echo -e "${C}Hostname:${N}   $HOSTNAME"
    echo -e "${C}Username:${N}   $USERNAME"
    echo -e "${C}SSH Port:${N}   $SSH_PORT"
    echo -e "${C}RAM:${N}        ${MEMORY}MB"
    echo -e "${C}CPU:${N}        $CPUS"
    echo -e "${C}Disk:${N}       $DISK_SIZE"
    echo -e "${C}Status:${N}     $status"
    echo -e "${C}KVM:${N}        $KVM_ACCEL"
    echo -e "${C}GUI:${N}        $GUI_MODE"
    echo -e "${C}Created:${N}    $CREATED"

    echo -e "${P}════════════════════════════════════════${N}"
    echo

    pause
}

# ============================================================
#                    DELETE VM
# ============================================================

delete_vm() {

    local vm="$1"

    load_vm "$vm" || return 1

    echo
    warn "This will delete VM '$vm' and its disk."

    read -rp "$(echo -e "${R}Type DELETE to continue: ${N}")" confirm

    [[ "$confirm" == "DELETE" ]] || {
        warn "Cancelled."
        return
    }

    vm_running "$vm" && stop_vm "$vm"

    rm -f \
        "$VM_DIR/$vm.conf" \
        "$VM_DIR/$vm.qcow2" \
        "$VM_DIR/$vm.img" \
        "$VM_DIR/$vm-seed.iso" \
        "$STATE_DIR/$vm.pid" \
        "$STATE_DIR/$vm.log"

    success "VM deleted."
}

# ============================================================
#                    RESIZE VM
# ============================================================

resize_vm() {

    local vm="$1"

    load_vm "$vm" || return 1

    if vm_running "$vm"; then
        error "Stop the VM first."
        return
    fi

    echo

    read -rp "$(echo -e "${LP}New disk size [$DISK_SIZE]: ${N}")" new_size
    new_size="${new_size:-$DISK_SIZE}"

    if ! [[ "$new_size" =~ ^[0-9]+[GgMm]$ ]]; then
        error "Invalid size."
        return
    fi

    qemu-img resize "$IMG_FILE" "$new_size"

    DISK_SIZE="$new_size"

    save_vm

    success "Disk resized to $new_size."
}

# ============================================================
#                    PERFORMANCE
# ============================================================

performance() {

    local vm="$1"

    load_vm "$vm" || return 1

    local pid

    pid="$(get_pid "$vm" 2>/dev/null || true)"

    echo
    echo -e "${P}════════════ PERFORMANCE ════════════${N}"

    if [[ -n "$pid" ]]; then

        ps -p "$pid" \
            -o pid,%cpu,%mem,rss,vsz,etime \
            --no-headers

        echo

        echo "Host memory:"
        free -h

    else

        echo -e "${Y}VM is stopped.${N}"
        echo
        echo "Configured RAM : ${MEMORY}MB"
        echo "Configured CPU : $CPUS"
        echo "Configured Disk: $DISK_SIZE"

    fi

    echo -e "${P}═════════════════════════════════════${N}"

    pause
}

# ============================================================
#                    VM SELECTOR
# ============================================================

choose_vm() {

    local action="$1"

    mapfile -t VMS < <(get_vms)

    if (( ${#VMS[@]} == 0 )); then
        warn "No VMs available."
        pause
        return
    fi

    echo

    for i in "${!VMS[@]}"; do

        local state="OFF"

        vm_running "${VMS[$i]}" &&
            state="ON"

        echo -e "  ${P}$((i+1)))${N} ${VMS[$i]} ${G}[$state]${N}"

    done

    echo

    read -rp "$(echo -e "${LP}VM number: ${N}")" num

    if ! [[ "$num" =~ ^[0-9]+$ ]] ||
       (( num < 1 || num > ${#VMS[@]} )); then

        error "Invalid VM."
        pause
        return
    fi

    "$action" "${VMS[$((num-1))]}"
}

# ============================================================
#                    KVM MANAGER
# ============================================================

kvm_manager() {

    check_kvm

    while true; do

        header

        mapfile -t VMS < <(get_vms)

        echo -e "${D}VM Directory:${N} $VM_DIR"
        echo -e "${D}Acceleration:${N} $KVM_ACCEL"
        echo

        if (( ${#VMS[@]} )); then

            echo -e "${P}Virtual Machines:${N}"

            for i in "${!VMS[@]}"; do

                local state="Stopped"

                vm_running "${VMS[$i]}" &&
                    state="Running"

                printf "  ${P}%2d)${N} %-25s ${C}%s${N}\n" \
                    "$((i+1))" \
                    "${VMS[$i]}" \
                    "$state"
            done

            echo
        else
            echo -e "${D}No VMs created.${N}"
            echo
        fi

        echo -e "${P}════════════════ KVM MAKER ════════════════${N}"

        echo -e "  ${P}1)${N} Create VM"

        if (( ${#VMS[@]} )); then
            echo -e "  ${P}2)${N} Start VM"
            echo -e "  ${P}3)${N} Stop VM"
            echo -e "  ${P}4)${N} VM Info"
            echo -e "  ${P}5)${N} Delete VM"
            echo -e "  ${P}6)${N} Resize Disk"
            echo -e "  ${P}7)${N} Performance"
        fi

        echo -e "  ${R}0)${N} Exit"
        echo

        read -rp "$(echo -e "${LP}Option: ${N}")" opt

        case "$opt" in

            1)
                create_vm
                pause
                ;;

            2)
                choose_vm start_vm
                ;;

            3)
                choose_vm stop_vm
                ;;

            4)
                choose_vm vm_info
                ;;

            5)
                choose_vm delete_vm
                ;;

            6)
                choose_vm resize_vm
                pause
                ;;

            7)
                choose_vm performance
                ;;

            0)
                success "Returning to main menu."
                return
                ;;

            *)
                error "Invalid option."
                sleep 0.4
                ;;

        esac
    done
}

# ============================================================
#                    MAIN MENU
# ============================================================

main_menu() {

    check_root

    while true; do

        header

        echo
        echo -e "${P}╔════════════════════════════════════════════════════════════╗${N}"
        echo -e "${P}║${N}              ${W}ZyroCloud Installer${N}                     ${P}║${N}"
        echo -e "${P}║${N}                   ${W}KVM MAKER${N}                            ${P}║${N}"
        echo -e "${P}╚════════════════════════════════════════════════════════════╝${N}"

        echo
        echo -e "  ${P}1)${N} Install KVM"
        echo -e "  ${R}0)${N} Exit"
        echo

        read -rp "$(echo -e "${LP}Select option: ${N}")" option

        case "$option" in

            1)
                fast_anim "Starting ZyroCloud KVM Installer"
                install_kvm
                ;;

            0)
                echo
                fast_anim "Exiting"
                echo -e "${G}Goodbye!${N}"
                exit 0
                ;;

            *)
                error "Please select 1 or 0."
                sleep 0.5
                ;;

        esac
    done
}

# ============================================================
#                    CLEANUP
# ============================================================

cleanup() {
    rm -f \
        "$VM_DIR/.user-data" \
        "$VM_DIR/.meta-data" \
        "$VM_DIR"/*.tmp 2>/dev/null || true
}

trap cleanup EXIT

# ============================================================
#                    START
# ============================================================

main_menu
