#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="${ROOT_DIR:-/}"

destination_path() {
    local path="$1"

    if [[ "$ROOT_DIR" == "/" ]]; then
        printf '%s\n' "$path"
    else
        printf '%s%s\n' "${ROOT_DIR%/}" "$path"
    fi
}

install_directory() {
    local source="$1"
    local destination="$2"

    if [[ ! -d "$source" ]]; then
        echo "Missing directory: $source" >&2
        return 1
    fi

    mkdir -p "$destination"
    rsync -a --delete "$source/" "$destination/"
    echo "Installed directory: $destination"
}

install_file() {
    local source="$1"
    local destination="$2"
    local mode="${3:-0644}"

    if [[ ! -f "$source" ]]; then
        echo "Missing file: $source" >&2
        return 1
    fi

    mkdir -p "$(dirname "$destination")"
    install -m "$mode" "$source" "$destination"
    echo "Installed file: $destination"
}

echo "NomadOS system installer"
echo "Repository: $REPO_DIR"
echo "Target root: $ROOT_DIR"

WALLPAPER_DEST="$(
    destination_path "/usr/share/backgrounds/nomados/nomados-wallpaper.png"
)"

SDDM_THEME_DEST="$(
    destination_path "/usr/share/sddm/themes/sddm-astronaut-theme"
)"

SDDM_CONFIG_DEST="$(
    destination_path "/etc/sddm.conf.d"
)"

install_file \
    "$REPO_DIR/assets/wallpapers/nomados-wallpaper.png" \
    "$WALLPAPER_DEST"

install_directory \
    "$REPO_DIR/assets/themes/sddm/sddm-astronaut-theme" \
    "$SDDM_THEME_DEST"

install_file \
    "$REPO_DIR/system/sddm/etc/sddm.conf.d/10-theme.conf" \
    "$SDDM_CONFIG_DEST/10-theme.conf"

install_file \
    "$REPO_DIR/system/sddm/etc/sddm.conf.d/display.conf" \
    "$SDDM_CONFIG_DEST/display.conf"

echo
echo "Configuring NomadOS GRUB background..."

GRUB_IMAGE_SOURCE="$REPO_DIR/assets/grub/Snufkin.png"
GRUB_CONFIG_SOURCE="$REPO_DIR/system/grub/background.conf"

GRUB_IMAGE_DEST="$(
    destination_path "/boot/grub/backgrounds/Snufkin.png"
)"

GRUB_DEFAULT_DEST="$(
    destination_path "/etc/default/grub"
)"

if [[ ! -f "$GRUB_IMAGE_SOURCE" ]]; then
    echo "Missing GRUB image: $GRUB_IMAGE_SOURCE" >&2
    exit 1
fi

if [[ ! -f "$GRUB_CONFIG_SOURCE" ]]; then
    echo "Missing GRUB configuration fragment: $GRUB_CONFIG_SOURCE" >&2
    exit 1
fi

if [[ ! -f "$GRUB_DEFAULT_DEST" ]]; then
    echo "Missing GRUB defaults file: $GRUB_DEFAULT_DEST" >&2
    exit 1
fi

install_file \
    "$GRUB_IMAGE_SOURCE" \
    "$GRUB_IMAGE_DEST"

sed -i -E \
    '/^[[:space:]]*GRUB_(BACKGROUND|THEME)=/d' \
    "$GRUB_DEFAULT_DEST"

printf '\n' >> "$GRUB_DEFAULT_DEST"
cat "$GRUB_CONFIG_SOURCE" >> "$GRUB_DEFAULT_DEST"
printf '\n' >> "$GRUB_DEFAULT_DEST"

echo "Configured: $GRUB_DEFAULT_DEST"
echo "GRUB background: /boot/grub/backgrounds/Snufkin.png"

if [[ "$ROOT_DIR" == "/" ]]; then
    if (( EUID != 0 )); then
        echo "Root privileges are required to regenerate GRUB." >&2
        exit 1
    fi

    if ! command -v grub-mkconfig >/dev/null 2>&1; then
        echo "grub-mkconfig is unavailable." >&2
        exit 1
    fi

    grub-mkconfig -o /boot/grub/grub.cfg

elif [[ -x "$ROOT_DIR/usr/bin/grub-mkconfig" ]]; then
    if (( EUID != 0 )); then
        echo "Root privileges are required for the target system." >&2
        exit 1
    fi

    if ! command -v arch-chroot >/dev/null 2>&1; then
        echo "arch-chroot is required to regenerate target GRUB." >&2
        exit 1
    fi

    arch-chroot "$ROOT_DIR" \
        grub-mkconfig -o /boot/grub/grub.cfg
else
    echo "Filesystem-only test detected."
    echo "GRUB files were configured, but grub-mkconfig was skipped."
fi

echo
echo "NomadOS system files installed successfully."
