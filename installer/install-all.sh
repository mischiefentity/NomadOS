#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DRY_RUN="${DRY_RUN:-1}"
ENABLE_VIRTUALBOX="${ENABLE_VIRTUALBOX:-0}"
TARGET_HOME="${TARGET_HOME:-$HOME}"

if (( EUID == 0 )); then
    echo "Run this script as the regular target user, not as root." >&2
    echo "The script will request sudo only for system-wide steps." >&2
    exit 1
fi

if [[ "$TARGET_HOME" == "/root" ]]; then
    echo "Refusing to install user configuration into /root." >&2
    exit 1
fi

REQUIRED_SCRIPTS=(
    "$REPO_DIR/installer/install-repositories.sh"
    "$REPO_DIR/installer/install-packages.sh"
    "$REPO_DIR/installer/install-system.sh"
    "$REPO_DIR/installer/install-dotfiles.sh"
    "$REPO_DIR/installer/enable-services.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [[ ! -x "$script" ]]; then
        echo "Missing or non-executable installer: $script" >&2
        exit 1
    fi
done

run_step() {
    local description="$1"
    shift

    echo
    echo "==> $description"

    if [[ "$DRY_RUN" == "1" ]]; then
        printf 'DRY RUN:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

echo "NomadOS master installer"
echo "Repository: $REPO_DIR"
echo "Target home: $TARGET_HOME"
echo "Dry run: $DRY_RUN"
echo "VirtualBox profile: $ENABLE_VIRTUALBOX"

run_step \
    "Configure BlackArch repository and keyring" \
    sudo env ROOT_DIR=/ \
    "$REPO_DIR/installer/install-repositories.sh"

run_step \
    "Install NomadOS packages" \
    env DRY_RUN=0 \
    "$REPO_DIR/installer/install-packages.sh"

run_step \
    "Install system themes and configuration" \
    sudo env ROOT_DIR=/ \
    "$REPO_DIR/installer/install-system.sh"

run_step \
    "Install user dotfiles" \
    env TARGET_HOME="$TARGET_HOME" \
    "$REPO_DIR/installer/install-dotfiles.sh"

run_step \
    "Enable system services" \
    sudo env \
    ROOT_DIR=/ \
    DRY_RUN=0 \
    ENABLE_VIRTUALBOX="$ENABLE_VIRTUALBOX" \
    "$REPO_DIR/installer/enable-services.sh"

echo
if [[ "$DRY_RUN" == "1" ]]; then
    echo "NomadOS installation plan completed."
    echo "No system changes were made."
else
    echo "NomadOS installation completed successfully."
fi
