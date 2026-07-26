#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PROFILE="$REPO_DIR/archiso"
WORK_DIR="$REPO_DIR/work"
STAGED_PROFILE="$WORK_DIR/profile"
BUILD_WORK="$WORK_DIR/build"
OUT_DIR="$REPO_DIR/out"

if ! command -v mkarchiso >/dev/null 2>&1; then
    echo "Error: archiso is not installed."
    echo "Run: sudo pacman -S --needed archiso"
    exit 1
fi

if [[ ! -f "$SOURCE_PROFILE/profiledef.sh" ]]; then
    echo "Error: ArchISO profile is incomplete."
    echo "Missing: $SOURCE_PROFILE/profiledef.sh"
    exit 1
fi

if [[ ! -x "$REPO_DIR/scripts/stage-iso-profile.sh" ]]; then
    echo "Error: ISO staging script is missing or not executable."
    exit 1
fi

if [[ ! -x "$REPO_DIR/scripts/iso-preflight-check.sh" ]]; then
    echo "Error: ISO preflight validator is missing or not executable." >&2
    exit 1
fi

"$REPO_DIR/scripts/iso-preflight-check.sh"

sudo rm -rf "$WORK_DIR"
mkdir -p "$OUT_DIR" "$WORK_DIR"

"$REPO_DIR/scripts/stage-iso-profile.sh" \
    "$STAGED_PROFILE"

sudo mkarchiso \
    -v \
    -w "$BUILD_WORK" \
    -o "$OUT_DIR" \
    "$STAGED_PROFILE"

sudo chown -R "$(id -u):$(id -g)" "$OUT_DIR"

echo
echo "Build complete."
echo "ISO files are in: $OUT_DIR"
