#!/usr/bin/env bash
set -Eeuo pipefail

PAYLOAD="/opt/nomados"
TARGET_ROOT="/mnt"
LOG_FILE="/var/log/nomados-install.log"

die() {
    echo
    echo "ERROR: $*" >&2
    exit 1
}

cleanup_mounts() {
    if mountpoint -q "$TARGET_ROOT" 2>/dev/null; then
        echo "Cleaning up mounted target filesystems..."
        umount -R "$TARGET_ROOT" 2>/dev/null || true
    fi
}

on_error() {
    local exit_code=$?
    echo
    echo "Installation failed near line $1."
    cleanup_mounts
    echo "Log: $LOG_FILE"
    exit "$exit_code"
}

on_interrupt() {
    echo
    echo "Installation interrupted."
    cleanup_mounts
    exit 130
}

trap 'on_error $LINENO' ERR
trap on_interrupt INT TERM

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        die "Required command is unavailable: $1"
}

partition_path() {
    local disk="$1"
    local number="$2"

    if [[ "$disk" =~ [0-9]$ ]]; then
        printf '%sp%s\n' "$disk" "$number"
    else
        printf '%s%s\n' "$disk" "$number"
    fi
}

if (( EUID != 0 )); then
    die "Run the installer with sudo: sudo nomados-install"
fi

# Prevent accidental execution from an installed system.
if [[ ! -d /run/archiso ]]; then
    die "This installer may only be run from the NomadOS live ISO."
fi

if [[ ! -d "$PAYLOAD" ]]; then
    die "The embedded NomadOS payload is missing: $PAYLOAD"
fi

for command in \
    arch-chroot \
    btrfs \
    curl \
    findmnt \
    genfstab \
    lscpu \
    lsblk \
    mkfs.btrfs \
    mkfs.fat \
    mount \
    mountpoint \
    pacstrap \
    partprobe \
    rsync \
    sgdisk \
    udevadm \
    wipefs
do
    require_command "$command"
done

touch "$LOG_FILE"
chmod 0600 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

clear

cat <<'BANNER'
====================================================
               NomadOS Installer
====================================================

This installer creates a fresh, preconfigured NomadOS
system using Btrfs, AwesomeWM, SDDM, Zsh, BlackArch,
the NomadOS desktop environment, and the GRUB artwork.

WARNING: The selected disk will be completely erased.
BANNER

echo
echo "Checking internet access..."

curl -fsI --connect-timeout 10 https://archlinux.org >/dev/null ||
    die "No working internet connection was detected."

echo "Internet connection detected."
echo

echo "Available installation disks:"
echo

lsblk -dpno NAME,SIZE,MODEL,TYPE |
    awk '$NF == "disk" {print}'

echo
read -rp "Enter the full target disk path, such as /dev/sda: " TARGET_DISK

[[ -b "$TARGET_DISK" ]] ||
    die "Not a block device: $TARGET_DISK"

[[ "$(lsblk -dnro TYPE "$TARGET_DISK")" == "disk" ]] ||
    die "The selected device is not a whole disk."

# Prevent erasing the device that contains the running live ISO.
LIVE_SOURCE="$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null || true)"
LIVE_DISK=""

if [[ "$LIVE_SOURCE" == /dev/* ]]; then
    LIVE_PARENT="$(lsblk -ndo PKNAME "$LIVE_SOURCE" 2>/dev/null || true)"

    if [[ -n "$LIVE_PARENT" ]]; then
        LIVE_DISK="/dev/$LIVE_PARENT"
    else
        LIVE_DISK="$LIVE_SOURCE"
    fi
fi

if [[ -n "$LIVE_DISK" && "$TARGET_DISK" == "$LIVE_DISK" ]]; then
    die "Refusing to erase the active NomadOS installation medium: $LIVE_DISK"
fi

mapfile -t ACTIVE_MOUNTS < <(
    lsblk -nrpo MOUNTPOINT "$TARGET_DISK" |
        awk 'NF'
)

if (( ${#ACTIVE_MOUNTS[@]} > 0 )); then
    echo "Mounted filesystems were found on $TARGET_DISK:"
    printf '  %s\n' "${ACTIVE_MOUNTS[@]}"
    die "Unmount the disk before installing."
fi

while true; do
    read -rp "New username: " NEW_USER

    if [[ "$NEW_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        break
    fi

    echo "Use lowercase letters, numbers, underscores, or hyphens."
done

while true; do
    read -rp "Computer hostname [nomados]: " HOSTNAME_VALUE
    HOSTNAME_VALUE="${HOSTNAME_VALUE:-nomados}"

    if [[ "$HOSTNAME_VALUE" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{0,62}$ ]]; then
        break
    fi

    echo "The hostname contains unsupported characters."
done

while true; do
    read -rp "Timezone [UTC]: " TIMEZONE
    TIMEZONE="${TIMEZONE:-UTC}"

    if [[ -e "/usr/share/zoneinfo/$TIMEZONE" ]]; then
        break
    fi

    echo "Unknown timezone: $TIMEZONE"
    echo "Example: America/Chicago"
done

while true; do
    read -rsp "Password for $NEW_USER: " USER_PASSWORD
    echo
    read -rsp "Confirm password: " USER_PASSWORD_CONFIRM
    echo

    if [[ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" ]]; then
        echo "Passwords did not match."
        continue
    fi

    if (( ${#USER_PASSWORD} < 8 )); then
        echo "Use a password containing at least eight characters."
        continue
    fi

    if [[ "$USER_PASSWORD" == *:* ]]; then
        echo "The password cannot contain a colon."
        continue
    fi

    break
done

if [[ -d /sys/firmware/efi ]]; then
    BOOT_MODE="UEFI"
else
    BOOT_MODE="BIOS"
fi

VIRTUALIZATION="$(systemd-detect-virt 2>/dev/null || true)"

if [[ "$VIRTUALIZATION" == "oracle" ]]; then
    ENABLE_VIRTUALBOX=1
else
    ENABLE_VIRTUALBOX=0
fi

echo
echo "Installation summary"
echo "--------------------"
echo "Disk:            $TARGET_DISK"
echo "Username:        $NEW_USER"
echo "Hostname:        $HOSTNAME_VALUE"
echo "Timezone:        $TIMEZONE"
echo "Boot mode:       $BOOT_MODE"
echo "Virtualization:  ${VIRTUALIZATION:-none}"
echo "Btrfs layout:    @, @home, @log, @pkg"
echo
echo "ALL DATA ON $TARGET_DISK WILL BE DESTROYED."
echo

read -rp "Type ERASE $TARGET_DISK to continue: " CONFIRMATION

[[ "$CONFIRMATION" == "ERASE $TARGET_DISK" ]] ||
    die "Installation cancelled."

echo
echo "Partitioning $TARGET_DISK..."

umount -R "$TARGET_ROOT" 2>/dev/null || true
wipefs --all --force "$TARGET_DISK"
sgdisk --zap-all "$TARGET_DISK"

if [[ "$BOOT_MODE" == "UEFI" ]]; then
    sgdisk \
        --new=1:0:+1G \
        --typecode=1:ef00 \
        --change-name=1:NOMADOS_EFI \
        "$TARGET_DISK"

    sgdisk \
        --new=2:0:0 \
        --typecode=2:8300 \
        --change-name=2:NOMADOS_ROOT \
        "$TARGET_DISK"
else
    sgdisk \
        --new=1:0:+2M \
        --typecode=1:ef02 \
        --change-name=1:NOMADOS_BIOS \
        "$TARGET_DISK"

    sgdisk \
        --new=2:0:0 \
        --typecode=2:8300 \
        --change-name=2:NOMADOS_ROOT \
        "$TARGET_DISK"
fi

partprobe "$TARGET_DISK"
udevadm settle

BOOT_PARTITION="$(partition_path "$TARGET_DISK" 1)"
ROOT_PARTITION="$(partition_path "$TARGET_DISK" 2)"

for attempt in {1..10}; do
    [[ -b "$ROOT_PARTITION" ]] && break
    sleep 1
done

[[ -b "$ROOT_PARTITION" ]] ||
    die "The root partition did not appear: $ROOT_PARTITION"

if [[ "$BOOT_MODE" == "UEFI" ]]; then
    [[ -b "$BOOT_PARTITION" ]] ||
        die "The EFI partition did not appear: $BOOT_PARTITION"

    mkfs.fat -F32 -n NOMADOS_EFI "$BOOT_PARTITION"
fi

mkfs.btrfs -f -L NOMADOS_ROOT "$ROOT_PARTITION"

echo
echo "Creating Btrfs subvolumes..."

mount "$ROOT_PARTITION" "$TARGET_ROOT"

btrfs subvolume create "$TARGET_ROOT/@"
btrfs subvolume create "$TARGET_ROOT/@home"
btrfs subvolume create "$TARGET_ROOT/@log"
btrfs subvolume create "$TARGET_ROOT/@pkg"

umount "$TARGET_ROOT"

BTRFS_OPTIONS="noatime,compress=zstd:3,space_cache=v2"

mount \
    -o "$BTRFS_OPTIONS,subvol=@" \
    "$ROOT_PARTITION" \
    "$TARGET_ROOT"

mkdir -p \
    "$TARGET_ROOT/home" \
    "$TARGET_ROOT/var/log" \
    "$TARGET_ROOT/var/cache/pacman/pkg" \
    "$TARGET_ROOT/boot"

mount \
    -o "$BTRFS_OPTIONS,subvol=@home" \
    "$ROOT_PARTITION" \
    "$TARGET_ROOT/home"

mount \
    -o "$BTRFS_OPTIONS,subvol=@log" \
    "$ROOT_PARTITION" \
    "$TARGET_ROOT/var/log"

mount \
    -o "$BTRFS_OPTIONS,subvol=@pkg" \
    "$ROOT_PARTITION" \
    "$TARGET_ROOT/var/cache/pacman/pkg"

if [[ "$BOOT_MODE" == "UEFI" ]]; then
    mount "$BOOT_PARTITION" "$TARGET_ROOT/boot"
fi

echo
echo "Installing the base Arch Linux system..."

CPU_VENDOR="$(
    lscpu |
        awk -F: '/Vendor ID/ {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
            print $2
            exit
        }'
)"

MICROCODE_PACKAGES=()

case "$CPU_VENDOR" in
    GenuineIntel)
        MICROCODE_PACKAGES=(intel-ucode)
        ;;
    AuthenticAMD)
        MICROCODE_PACKAGES=(amd-ucode)
        ;;
    *)
        echo "No Intel or AMD microcode package selected."
        ;;
esac

if (( ${#MICROCODE_PACKAGES[@]} > 0 )); then
    echo "CPU microcode: ${MICROCODE_PACKAGES[*]}"
fi

pacstrap -K "$TARGET_ROOT" \
    base \
    linux \
    linux-firmware \
    archlinux-keyring \
    btrfs-progs \
    efibootmgr \
    git \
    grub \
    networkmanager \
    rsync \
    sudo \
    zsh \
    "${MICROCODE_PACKAGES[@]}"

genfstab -U "$TARGET_ROOT" > "$TARGET_ROOT/etc/fstab"

echo
echo "Copying the embedded NomadOS payload..."

mkdir -p "$TARGET_ROOT/opt/nomados"

rsync -a --delete \
    "$PAYLOAD/" \
    "$TARGET_ROOT/opt/nomados/"

echo
echo "Configuring locale, timezone, and hostname..."

ln -sf \
    "/usr/share/zoneinfo/$TIMEZONE" \
    "$TARGET_ROOT/etc/localtime"

arch-chroot "$TARGET_ROOT" hwclock --systohc

sed -i \
    's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
    "$TARGET_ROOT/etc/locale.gen"

arch-chroot "$TARGET_ROOT" locale-gen

printf 'LANG=en_US.UTF-8\n' \
    > "$TARGET_ROOT/etc/locale.conf"

printf 'KEYMAP=us\n' \
    > "$TARGET_ROOT/etc/vconsole.conf"

printf '%s\n' "$HOSTNAME_VALUE" \
    > "$TARGET_ROOT/etc/hostname"

cat > "$TARGET_ROOT/etc/hosts" <<HOSTSEOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 ${HOSTNAME_VALUE}.localdomain ${HOSTNAME_VALUE}
HOSTSEOF

echo
echo "Creating user account..."

arch-chroot "$TARGET_ROOT" \
    useradd \
    --create-home \
    --groups wheel \
    --shell /usr/bin/zsh \
    "$NEW_USER"

printf '%s:%s\n' "$NEW_USER" "$USER_PASSWORD" |
    arch-chroot "$TARGET_ROOT" chpasswd

unset USER_PASSWORD USER_PASSWORD_CONFIRM

arch-chroot "$TARGET_ROOT" passwd --lock root

install -Dm440 /dev/stdin \
    "$TARGET_ROOT/etc/sudoers.d/10-nomados-wheel" <<'SUDOEOF'
%wheel ALL=(ALL:ALL) ALL
SUDOEOF

echo
echo "Configuring BlackArch repositories..."

arch-chroot "$TARGET_ROOT" \
    env ROOT_DIR=/ \
    /opt/nomados/installer/install-repositories.sh

echo
echo "Installing the complete NomadOS package set..."

arch-chroot "$TARGET_ROOT" \
    env DRY_RUN=0 \
    /opt/nomados/installer/install-packages.sh

echo
echo "Installing the GRUB bootloader..."

if [[ "$BOOT_MODE" == "UEFI" ]]; then
    arch-chroot "$TARGET_ROOT" \
        grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot \
        --bootloader-id=NomadOS
else
    arch-chroot "$TARGET_ROOT" \
        grub-install \
        --target=i386-pc \
        "$TARGET_DISK"
fi

echo
echo "Installing NomadOS themes and system configuration..."

arch-chroot "$TARGET_ROOT" \
    env ROOT_DIR=/ \
    /opt/nomados/installer/install-system.sh

echo
echo "Installing user configuration..."

arch-chroot "$TARGET_ROOT" \
    runuser -u "$NEW_USER" -- \
    env TARGET_HOME="/home/$NEW_USER" \
    /opt/nomados/installer/install-dotfiles.sh

arch-chroot "$TARGET_ROOT" \
    chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER"

echo
echo "Creating Snapper configurations..."

arch-chroot "$TARGET_ROOT" \
    snapper -c root create-config / ||
    echo "Root Snapper configuration already exists or could not be created."

arch-chroot "$TARGET_ROOT" \
    snapper -c home create-config /home ||
    echo "Home Snapper configuration already exists or could not be created."

echo
echo "Enabling NomadOS services..."

arch-chroot "$TARGET_ROOT" \
    env \
    ROOT_DIR=/ \
    DRY_RUN=0 \
    ENABLE_VIRTUALBOX="$ENABLE_VIRTUALBOX" \
    /opt/nomados/installer/enable-services.sh

arch-chroot "$TARGET_ROOT" \
    systemctl set-default graphical.target

arch-chroot "$TARGET_ROOT" \
    mkinitcpio -P

sync

echo
echo "Unmounting the installed system..."

umount -R "$TARGET_ROOT"

cat <<'COMPLETE'

====================================================
          NomadOS installation completed
====================================================

Remove the installation media and reboot.

The root account is locked. Use the user account created
during installation and sudo for administrative commands.

COMPLETE
