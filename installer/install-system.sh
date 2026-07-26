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
echo "NomadOS system files installed successfully."
