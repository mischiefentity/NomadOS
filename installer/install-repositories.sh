#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="${ROOT_DIR:-/}"

target_path() {
    local path="$1"

    if [[ "$ROOT_DIR" == "/" ]]; then
        printf '%s\n' "$path"
    else
        printf '%s%s\n' "${ROOT_DIR%/}" "$path"
    fi
}

PACMAN_CONF="$(target_path "/etc/pacman.conf")"
MIRRORLIST_DEST="$(target_path "/etc/pacman.d/blackarch-mirrorlist")"
KEYRING_DEST="$(target_path "/usr/share/pacman/keyrings")"

REPO_FRAGMENT="$REPO_DIR/system/pacman/blackarch.repo"
MIRRORLIST_SOURCE="$REPO_DIR/system/pacman/etc/pacman.d/blackarch-mirrorlist"
KEYRING_SOURCE="$REPO_DIR/system/pacman/usr/share/pacman/keyrings"

echo "NomadOS repository installer"
echo "Repository: $REPO_DIR"
echo "Target root: $ROOT_DIR"
echo

if [[ ! -f "$PACMAN_CONF" ]]; then
    echo "Missing Pacman configuration: $PACMAN_CONF" >&2
    exit 1
fi

if [[ ! -f "$REPO_FRAGMENT" ]]; then
    echo "Missing repository fragment: $REPO_FRAGMENT" >&2
    exit 1
fi

if [[ ! -f "$MIRRORLIST_SOURCE" ]]; then
    echo "Missing BlackArch mirror list: $MIRRORLIST_SOURCE" >&2
    exit 1
fi

for file in blackarch.gpg blackarch-trusted blackarch-revoked; do
    if [[ ! -f "$KEYRING_SOURCE/$file" ]]; then
        echo "Missing BlackArch keyring file: $KEYRING_SOURCE/$file" >&2
        exit 1
    fi
done

install -Dm644 "$MIRRORLIST_SOURCE" "$MIRRORLIST_DEST"
echo "Installed: $MIRRORLIST_DEST"

for file in blackarch.gpg blackarch-trusted blackarch-revoked; do
    install -Dm644 \
        "$KEYRING_SOURCE/$file" \
        "$KEYRING_DEST/$file"

    echo "Installed: $KEYRING_DEST/$file"
done

if grep -qE '^[[:space:]]*\[blackarch\][[:space:]]*$' "$PACMAN_CONF"; then
    echo "BlackArch repository is already configured."
else
    printf '\n' >> "$PACMAN_CONF"
    cat "$REPO_FRAGMENT" >> "$PACMAN_CONF"
    printf '\n' >> "$PACMAN_CONF"

    echo "Added BlackArch repository to: $PACMAN_CONF"
fi

initialize_keyring() {
    pacman-key --init
    pacman-key --populate archlinux
    pacman-key --populate blackarch
}

if [[ "$ROOT_DIR" == "/" ]]; then
    if (( EUID != 0 )); then
        echo "Run this installer with sudo when targeting the real system." >&2
        exit 1
    fi

    echo
    echo "Initializing the live Pacman keyring..."
    initialize_keyring

elif [[ -x "$ROOT_DIR/usr/bin/pacman-key" ]]; then
    if (( EUID != 0 )); then
        echo "Root privileges are required for an installed target system." >&2
        exit 1
    fi

    if ! command -v arch-chroot >/dev/null 2>&1; then
        echo "arch-chroot is required to initialize the target keyring." >&2
        exit 1
    fi

    echo
    echo "Initializing the target Pacman keyring..."

    arch-chroot "$ROOT_DIR" pacman-key --init
    arch-chroot "$ROOT_DIR" pacman-key --populate archlinux
    arch-chroot "$ROOT_DIR" pacman-key --populate blackarch

else
    echo
    echo "Filesystem-only test detected."
    echo "Pacman keyring initialization was skipped."
fi

echo
echo "Replacing temporary BlackArch seed files with package-owned versions..."

OVERWRITE_PATHS='usr/share/pacman/keyrings/blackarch*,etc/pacman.d/blackarch-mirrorlist'

if [[ "$ROOT_DIR" == "/" ]]; then
    pacman -Sy         --needed         --noconfirm         --overwrite "$OVERWRITE_PATHS"         blackarch-keyring         blackarch-mirrorlist

    pacman-key --populate blackarch

elif [[ -x "$ROOT_DIR/usr/bin/pacman" ]]; then
    if (( EUID != 0 )); then
        echo "Root privileges are required for the target system." >&2
        exit 1
    fi

    if ! command -v arch-chroot >/dev/null 2>&1; then
        echo "arch-chroot is required for the target system." >&2
        exit 1
    fi

    arch-chroot "$ROOT_DIR"         pacman -Sy         --needed         --noconfirm         --overwrite "$OVERWRITE_PATHS"         blackarch-keyring         blackarch-mirrorlist

    arch-chroot "$ROOT_DIR"         pacman-key --populate blackarch
else
    echo "Filesystem-only test detected."
    echo "BlackArch package ownership conversion was skipped."
fi

echo
echo "NomadOS repository configuration installed successfully."
