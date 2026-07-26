#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="${ROOT_DIR:-/}"
DRY_RUN="${DRY_RUN:-0}"
ENABLE_VIRTUALBOX="${ENABLE_VIRTUALBOX:-0}"

BASE_LIST="$REPO_DIR/system/services/enabled.txt"
VIRTUALBOX_LIST="$REPO_DIR/system/services/virtualbox.txt"

read_service_list() {
    local file="$1"

    [[ -f "$file" ]] || return 0

    grep -Ev '^[[:space:]]*(#|$)' "$file"
}

enable_service() {
    local service="$1"

    if [[ "$DRY_RUN" == "1" ]]; then
        printf 'DRY RUN: systemctl --root=%q enable %q\n' \
            "$ROOT_DIR" "$service"
        return
    fi

    if ! systemctl --root="$ROOT_DIR" list-unit-files "$service" \
        --no-legend 2>/dev/null |
        grep -q "^${service}[[:space:]]"; then

        echo "Warning: unit is unavailable, skipping: $service" >&2
        return
    fi

    systemctl --root="$ROOT_DIR" enable "$service"
    echo "Enabled: $service"
}

if [[ "$DRY_RUN" != "1" && "$EUID" -ne 0 ]]; then
    echo "Run this installer with sudo unless DRY_RUN=1." >&2
    exit 1
fi

echo "NomadOS service installer"
echo "Repository: $REPO_DIR"
echo "Target root: $ROOT_DIR"
echo "Dry run: $DRY_RUN"
echo "VirtualBox profile: $ENABLE_VIRTUALBOX"
echo

while IFS= read -r service; do
    enable_service "$service"
done < <(read_service_list "$BASE_LIST")

if [[ "$ENABLE_VIRTUALBOX" == "1" ]]; then
    echo
    echo "Enabling VirtualBox guest services..."

    while IFS= read -r service; do
        enable_service "$service"
    done < <(read_service_list "$VIRTUALBOX_LIST")
fi

echo
echo "NomadOS service configuration completed."
