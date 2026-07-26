#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OFFICIAL_LIST="$REPO_DIR/packages/official.txt"
FOREIGN_LIST="$REPO_DIR/packages/aur.txt"

DRY_RUN="${DRY_RUN:-0}"

if (( EUID == 0 )); then
    SUDO=()
else
    SUDO=(sudo)
fi

run_command() {
    if [[ "$DRY_RUN" == "1" ]]; then
        printf 'DRY RUN:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

read_package_list() {
    local package_file="$1"

    [[ -f "$package_file" ]] || return 0

    grep -Ev '^[[:space:]]*(#|$)' "$package_file"
}

echo "NomadOS package installer"
echo "Repository: $REPO_DIR"
echo "Dry run: $DRY_RUN"
echo

mapfile -t OFFICIAL_PACKAGES < <(
    read_package_list "$OFFICIAL_LIST"
)

if (( ${#OFFICIAL_PACKAGES[@]} > 0 )); then
    echo "Installing ${#OFFICIAL_PACKAGES[@]} official packages..."

    run_command \
        "${SUDO[@]}" \
        pacman -Syu --needed \
        "${OFFICIAL_PACKAGES[@]}"
else
    echo "No official packages found."
fi

echo

mapfile -t FOREIGN_PACKAGES < <(
    read_package_list "$FOREIGN_LIST"
)

if (( ${#FOREIGN_PACKAGES[@]} == 0 )); then
    echo "No foreign/AUR packages found."
elif command -v yay >/dev/null 2>&1; then
    echo "Installing ${#FOREIGN_PACKAGES[@]} foreign packages with yay..."

    run_command \
        yay -S --needed \
        "${FOREIGN_PACKAGES[@]}"
elif command -v paru >/dev/null 2>&1; then
    echo "Installing ${#FOREIGN_PACKAGES[@]} foreign packages with paru..."

    run_command \
        paru -S --needed \
        "${FOREIGN_PACKAGES[@]}"
else
    echo "Foreign packages were found, but neither yay nor paru is installed." >&2
    echo "Skipping foreign package installation." >&2
fi

echo
echo "NomadOS package installation completed."
