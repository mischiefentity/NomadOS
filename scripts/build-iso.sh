#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="$REPO_DIR/archiso"
WORK_DIR="$REPO_DIR/work"
OUT_DIR="$REPO_DIR/out"

if ! command -v mkarchiso >/dev/null 2>&1; then
    echo "Error: archiso is not installed."
    echo "Run: sudo pacman -S --needed archiso"
    exit 1
fi

if [[ ! -f "$PROFILE_DIR/profiledef.sh" ]]; then
    echo "Error: ArchISO profile is incomplete."
    echo "Missing: $PROFILE_DIR/profiledef.sh"
    exit 1
fi

sudo rm -rf "$WORK_DIR"
mkdir -p "$OUT_DIR"

sudo mkarchiso \
    -v \
    -w "$WORK_DIR" \
    -o "$OUT_DIR" \
    "$PROFILE_DIR"

echo
sudo chown -R "$(id -u):$(id -g)" "$OUT_DIR"
echo "Build complete."
echo "ISO files are in: $OUT_DIR"
