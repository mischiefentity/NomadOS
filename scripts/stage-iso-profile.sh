#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PROFILE="$REPO_DIR/archiso"
STAGE_DIR="${1:-$REPO_DIR/work/profile}"

AIROOTFS="$STAGE_DIR/airootfs"
SKEL="$AIROOTFS/etc/skel"
PAYLOAD="$AIROOTFS/opt/nomados"

echo "Staging NomadOS ArchISO profile..."
echo "Source: $SOURCE_PROFILE"
echo "Target: $STAGE_DIR"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

# Copy the base ArchISO profile.
rsync -a "$SOURCE_PROFILE/" "$STAGE_DIR/"

# Synchronize the current tested desktop configuration.
mkdir -p "$SKEL/.config"

rsync -a --delete \
    "$REPO_DIR/dotfiles/awesome/" \
    "$SKEL/.config/awesome/"

rsync -a --delete \
    "$REPO_DIR/dotfiles/kitty/" \
    "$SKEL/.config/kitty/"

rsync -a --delete \
    "$REPO_DIR/dotfiles/nvim/" \
    "$SKEL/.config/nvim/"

rsync -a --delete \
    "$REPO_DIR/dotfiles/picom/" \
    "$SKEL/.config/picom/"

# Synchronize available Zsh files.
for file in .zshrc .zprofile .zshenv .p10k.zsh; do
    source_file="$REPO_DIR/dotfiles/zsh/$file"

    if [[ -f "$source_file" ]]; then
        install -Dm644 "$source_file" "$SKEL/$file"
    else
        rm -f "$SKEL/$file"
    fi
done

# Install the live-session wallpaper configuration.
install -Dm755 \
    "$REPO_DIR/dotfiles/feh/.fehbg" \
    "$SKEL/.fehbg"

install -Dm644 \
    "$REPO_DIR/assets/wallpapers/nomados-wallpaper.png" \
    "$AIROOTFS/usr/share/backgrounds/nomados/nomados-wallpaper.png"

# Install the tested SDDM theme.
mkdir -p "$AIROOTFS/usr/share/sddm/themes/sddm-astronaut-theme"

rsync -a --delete \
    "$REPO_DIR/assets/themes/sddm/sddm-astronaut-theme/" \
    "$AIROOTFS/usr/share/sddm/themes/sddm-astronaut-theme/"

# Embed the permanent-install configuration payload.
rm -rf "$PAYLOAD"
mkdir -p "$PAYLOAD"

for directory in installer packages system assets dotfiles; do
    rsync -a \
        "$REPO_DIR/$directory/" \
        "$PAYLOAD/$directory/"
done

mkdir -p "$PAYLOAD/scripts"

install -Dm755 \
    "$REPO_DIR/scripts/preflight-check.sh" \
    "$PAYLOAD/scripts/preflight-check.sh"

install -Dm644 \
    "$REPO_DIR/README.md" \
    "$PAYLOAD/README.md"

chmod +x "$PAYLOAD"/installer/*.sh

echo
echo "NomadOS ISO profile staged successfully."
