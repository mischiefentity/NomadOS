#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_HOME="${TARGET_HOME:-$HOME}"

echo "NomadOS dotfile installer"
echo "Repository: $REPO_DIR"
echo "Target home: $TARGET_HOME"

install_directory() {
    local source="$1"
    local destination="$2"

    if [[ ! -d "$source" ]]; then
        echo "Skipping missing directory: $source"
        return
    fi

    mkdir -p "$destination"
    rsync -a --delete "$source/" "$destination/"
    echo "Installed: $destination"
}

install_file() {
    local source="$1"
    local destination="$2"

    if [[ ! -f "$source" ]]; then
        echo "Skipping missing file: $source"
        return
    fi

    mkdir -p "$(dirname "$destination")"
    cp -a "$source" "$destination"
    echo "Installed: $destination"
}

install_directory \
    "$REPO_DIR/dotfiles/kitty" \
    "$TARGET_HOME/.config/kitty"

install_directory \
    "$REPO_DIR/dotfiles/awesome" \
    "$TARGET_HOME/.config/awesome"

install_directory \
    "$REPO_DIR/dotfiles/picom" \
    "$TARGET_HOME/.config/picom"

install_directory \
    "$REPO_DIR/dotfiles/nvim" \
    "$TARGET_HOME/.config/nvim"

install_file \
    "$REPO_DIR/dotfiles/zsh/.zshrc" \
    "$TARGET_HOME/.zshrc"

install_file \
    "$REPO_DIR/dotfiles/zsh/.zprofile" \
    "$TARGET_HOME/.zprofile"

install_file \
    "$REPO_DIR/dotfiles/zsh/.zshenv" \
    "$TARGET_HOME/.zshenv"

install_file \
    "$REPO_DIR/dotfiles/zsh/.p10k.zsh" \
    "$TARGET_HOME/.p10k.zsh"

install_file \
    "$REPO_DIR/dotfiles/feh/.fehbg" \
    "$TARGET_HOME/.fehbg"

[[ -f "$TARGET_HOME/.fehbg" ]] && chmod +x "$TARGET_HOME/.fehbg"

echo
echo "NomadOS dotfiles installed successfully."
