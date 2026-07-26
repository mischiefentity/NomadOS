#!/usr/bin/env bash

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0
WARNINGS=0

pass() {
    printf '[PASS] %s\n' "$1"
}

warn() {
    printf '[WARN] %s\n' "$1"
    ((WARNINGS++))
}

fail() {
    printf '[FAIL] %s\n' "$1"
    ((ERRORS++))
}

echo "NomadOS preflight validation"
echo "Repository: $REPO_DIR"
echo

cd "$REPO_DIR" || exit 1

required_files=(
    ".gitignore"
    "README.md"
    "installer/install-all.sh"
    "installer/install-dotfiles.sh"
    "installer/install-packages.sh"
    "installer/install-repositories.sh"
    "installer/install-system.sh"
    "installer/enable-services.sh"
    "packages/official.txt"
    "packages/aur.txt"
    "system/services/enabled.txt"
    "system/services/virtualbox.txt"
    "system/pacman/blackarch.repo"
    "system/pacman/etc/pacman.d/blackarch-mirrorlist"
    "system/pacman/usr/share/pacman/keyrings/blackarch.gpg"
    "system/pacman/usr/share/pacman/keyrings/blackarch-trusted"
    "system/pacman/usr/share/pacman/keyrings/blackarch-revoked"
    "assets/wallpapers/nomados-wallpaper.png"
    "inventory/environment.txt"
)

echo "==> Required files"

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        pass "$file"
    else
        fail "Missing file: $file"
    fi
done

echo
echo "==> Required directories"

required_directories=(
    "dotfiles/awesome"
    "dotfiles/kitty"
    "dotfiles/nvim"
    "dotfiles/picom"
    "dotfiles/zsh"
    "assets/themes/sddm/sddm-astronaut-theme"
)

for directory in "${required_directories[@]}"; do
    if [[ -d "$directory" ]]; then
        pass "$directory"
    else
        fail "Missing directory: $directory"
    fi
done

echo
echo "==> Shell script syntax and permissions"

while IFS= read -r script; do
    if bash -n "$script"; then
        pass "Valid syntax: $script"
    else
        fail "Invalid syntax: $script"
    fi

    if [[ -x "$script" ]]; then
        pass "Executable: $script"
    else
        fail "Not executable: $script"
    fi
done < <(
    find installer scripts \
        -maxdepth 1 \
        -type f \
        -name '*.sh' \
        -print |
    sort
)

echo
echo "==> Package manifests"

duplicate_packages="$(
    grep -Ev '^[[:space:]]*(#|$)' packages/official.txt |
    sort |
    uniq -d
)"

if [[ -z "$duplicate_packages" ]]; then
    pass "No duplicate official packages"
else
    fail "Duplicate packages found:"
    printf '%s\n' "$duplicate_packages"
fi

unavailable_packages="$(
    comm -23 \
        <(
            grep -Ev '^[[:space:]]*(#|$)' packages/official.txt |
            sort -u
        ) \
        <(
            pacman -Slq 2>/dev/null |
            sort -u
        )
)"

if [[ -z "$unavailable_packages" ]]; then
    pass "All official packages are available from configured repositories"
else
    fail "Packages unavailable from configured repositories:"
    printf '%s\n' "$unavailable_packages"
fi

echo
echo "==> Environment inventory"

allowed_environment_names='^(SHELL|LANG|LC_ALL|TERM|XDG_CURRENT_DESKTOP|XDG_SESSION_DESKTOP|XDG_SESSION_TYPE)$'

unexpected_environment_names="$(
    cut -d= -f1 inventory/environment.txt 2>/dev/null |
    grep -Ev "$allowed_environment_names" ||
    true
)"

if [[ -z "$unexpected_environment_names" ]]; then
    pass "Environment inventory contains only approved variables"
else
    fail "Unexpected environment variable names:"
    printf '%s\n' "$unexpected_environment_names"
fi

echo
echo "==> Hard-coded user paths"

hardcoded_files="$(
    grep -RIlE --exclude='preflight-check.sh' \
    '/home/[[:alnum:]_.-]+/' \
        installer \
        scripts \
        dotfiles \
        system \
        assets \
        packages \
        2>/dev/null ||
    true
)"

if [[ -z "$hardcoded_files" ]]; then
    pass "No hard-coded /home/nomad paths found"
else
    warn "Hard-coded /home/nomad path found in:"
    printf '%s\n' "$hardcoded_files"
fi

echo
echo "==> Possible credential assignments"

credential_files="$(
    grep -RIlE \
        '(API[_-]?KEY|ACCESS[_-]?TOKEN|AUTH[_-]?TOKEN|PASSWORD|PASSWD|PRIVATE[_-]?KEY|CLIENT[_-]?SECRET)[[:space:]]*=' \
        installer \
        scripts \
        dotfiles \
        system \
        packages \
        2>/dev/null ||
    true
)"

if [[ -z "$credential_files" ]]; then
    pass "No obvious credential assignments detected"
else
    warn "Review possible credential assignments in:"
    printf '%s\n' "$credential_files"
fi

echo
echo "==> Large repository assets"

large_files="$(
    find assets system dotfiles \
        -type f \
        -size +25M \
        -print 2>/dev/null ||
    true
)"

if [[ -z "$large_files" ]]; then
    pass "No files larger than 25 MiB found"
else
    warn "Large files found:"
    printf '%s\n' "$large_files"
fi

echo
echo "==> Git working tree"

if [[ -z "$(git status --short)" ]]; then
    pass "Git working tree is clean"
else
    warn "Git working tree contains uncommitted changes:"
    git status --short
fi

echo
echo "========================================"
echo "Preflight complete"
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"
echo "========================================"

if (( ERRORS > 0 )); then
    exit 1
fi

exit 0
