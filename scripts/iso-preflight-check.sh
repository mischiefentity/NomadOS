#!/usr/bin/env bash
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0
WARNINGS=0
STAGE_DIR=""

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

cleanup() {
    if [[ -n "$STAGE_DIR" && -d "$STAGE_DIR" ]]; then
        rm -rf "$STAGE_DIR"
    fi
}

trap cleanup EXIT

cd "$REPO_DIR" || exit 1

echo "NomadOS ISO preflight validation"
echo "Repository: $REPO_DIR"
echo

echo "==> Required source files"

required_files=(
    "archiso/profiledef.sh"
    "archiso/packages.x86_64"
    "archiso/pacman.conf"
    "archiso/airootfs/etc/sddm.conf.d/10-nomados.conf"
    "archiso/airootfs/etc/systemd/system/nomados-live-setup.service"
    "archiso/airootfs/usr/local/bin/nomados-live-setup"
    "archiso/airootfs/usr/share/applications/nomados-installer.desktop"
    "installer/nomados-install.sh"
    "installer/nomados-welcome.sh"
    "scripts/stage-iso-profile.sh"
    "scripts/build-iso.sh"
    "assets/grub/Snufkin.png"
    "assets/wallpapers/nomados-wallpaper.png"
    "assets/themes/sddm/sddm-astronaut-theme/metadata.desktop"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        pass "$file"
    else
        fail "Missing file: $file"
    fi
done

echo
echo "==> Shell syntax"

shell_files=(
    "archiso/profiledef.sh"
    "archiso/airootfs/usr/local/bin/nomados-live-setup"
    "installer/nomados-install.sh"
    "installer/nomados-welcome.sh"
    "scripts/stage-iso-profile.sh"
    "scripts/build-iso.sh"
)

for file in "${shell_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        continue
    fi

    if bash -n "$file"; then
        pass "Valid syntax: $file"
    else
        fail "Invalid syntax: $file"
    fi
done

echo
echo "==> Executable source programs"

executable_files=(
    "archiso/airootfs/usr/local/bin/nomados-live-setup"
    "installer/nomados-install.sh"
    "installer/nomados-welcome.sh"
    "scripts/stage-iso-profile.sh"
    "scripts/build-iso.sh"
)

for file in "${executable_files[@]}"; do
    if [[ -x "$file" ]]; then
        pass "Executable: $file"
    else
        fail "Not executable: $file"
    fi
done

echo
echo "==> Required live ISO packages"

required_packages=(
    arch-install-scripts
    awesome
    btrfs-progs
    curl
    dosfstools
    feh
    gptfdisk
    grub
    kitty
    networkmanager
    parted
    picom
    qt6-multimedia
    qt6-svg
    qt6-virtualkeyboard
    rsync
    sddm
    sudo
    xorg-server
    zsh
)

for package in "${required_packages[@]}"; do
    if grep -qxF "$package" archiso/packages.x86_64; then
        pass "ISO package: $package"
    else
        fail "Missing ISO package: $package"
    fi
done

duplicate_packages="$(
    sort archiso/packages.x86_64 |
        uniq -d
)"

if [[ -z "$duplicate_packages" ]]; then
    pass "No duplicate ISO packages"
else
    fail "Duplicate ISO packages:"
    printf '%s\n' "$duplicate_packages"
fi

echo
echo "==> Live-session configuration"

if grep -q '^User=nomad$' \
    archiso/airootfs/etc/sddm.conf.d/10-nomados.conf; then
    pass "SDDM autologin user is nomad"
else
    fail "SDDM autologin user is not configured"
fi

if grep -q '^Session=awesome$' \
    archiso/airootfs/etc/sddm.conf.d/10-nomados.conf; then
    pass "SDDM autologin session is AwesomeWM"
else
    fail "SDDM AwesomeWM autologin is not configured"
fi

if grep -q '^Current=sddm-astronaut-theme$' \
    archiso/airootfs/etc/sddm.conf.d/10-nomados.conf; then
    pass "Custom SDDM theme is configured"
else
    fail "Custom SDDM theme is not configured"
fi

if [[ ! -e \
    archiso/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service
]]; then
    pass "Live SSH autostart is disabled"
else
    fail "Live SSH autostart is still enabled"
fi

if grep -q \
    '\["/usr/local/bin/nomados-install"\]="0:0:755"' \
    archiso/profiledef.sh; then
    pass "Installer permission is recorded"
else
    fail "Installer permission is missing from profiledef.sh"
fi

if grep -q \
    '\["/usr/local/bin/nomados-welcome"\]="0:0:755"' \
    archiso/profiledef.sh; then
    pass "Welcome launcher permission is recorded"
else
    fail "Welcome launcher permission is missing from profiledef.sh"
fi

echo
echo "==> Installer safety guards"

if grep -q 'This installer may only be run from the NomadOS live ISO' \
    installer/nomados-install.sh; then
    pass "Installed-system execution guard is present"
else
    fail "Installed-system execution guard is missing"
fi

if grep -q 'Refusing to erase the active NomadOS installation medium' \
    installer/nomados-install.sh; then
    pass "Live-media disk protection is present"
else
    fail "Live-media disk protection is missing"
fi

if grep -q 'Type ERASE \$TARGET_DISK to continue' \
    installer/nomados-install.sh; then
    pass "Explicit disk-erasure confirmation is present"
else
    fail "Explicit disk-erasure confirmation is missing"
fi

echo
echo "==> Staged ISO profile"

STAGE_DIR="$(mktemp -d /tmp/nomados-iso-preflight.XXXXXX)"

if ./scripts/stage-iso-profile.sh "$STAGE_DIR"; then
    pass "ISO profile staged successfully"
else
    fail "ISO profile staging failed"
fi

staged_files=(
    "airootfs/usr/local/bin/nomados-install"
    "airootfs/usr/local/bin/nomados-welcome"
    "airootfs/usr/local/bin/nomados-live-setup"
    "airootfs/opt/nomados/installer/install-all.sh"
    "airootfs/opt/nomados/installer/nomados-install.sh"
    "airootfs/etc/skel/.config/awesome/rc.lua"
    "airootfs/etc/skel/.config/kitty/kitty.conf"
    "airootfs/etc/skel/.zshrc"
    "airootfs/usr/share/backgrounds/nomados/nomados-wallpaper.png"
    "airootfs/usr/share/sddm/themes/sddm-astronaut-theme/metadata.desktop"
    "airootfs/usr/share/applications/nomados-installer.desktop"
)

for relative_path in "${staged_files[@]}"; do
    if [[ -f "$STAGE_DIR/$relative_path" ]]; then
        pass "Staged: $relative_path"
    else
        fail "Missing from staged ISO: $relative_path"
    fi
done

for program in \
    "$STAGE_DIR/airootfs/usr/local/bin/nomados-install" \
    "$STAGE_DIR/airootfs/usr/local/bin/nomados-welcome" \
    "$STAGE_DIR/airootfs/usr/local/bin/nomados-live-setup"
do
    if [[ -x "$program" ]]; then
        pass "Staged executable: ${program#"$STAGE_DIR/"}"
    else
        fail "Staged program is not executable: ${program#"$STAGE_DIR/"}"
    fi

    if bash -n "$program"; then
        pass "Staged syntax valid: ${program#"$STAGE_DIR/"}"
    else
        fail "Staged syntax invalid: ${program#"$STAGE_DIR/"}"
    fi
done

if cmp -s \
    installer/nomados-install.sh \
    "$STAGE_DIR/airootfs/usr/local/bin/nomados-install"; then
    pass "Staged installer matches repository source"
else
    fail "Staged installer differs from repository source"
fi

if grep -q 'NomadOS live installer welcome screen' \
    "$STAGE_DIR/airootfs/etc/skel/.config/awesome/rc.lua"; then
    pass "Live welcome screen autostart is staged"
else
    fail "Live welcome screen autostart is missing"
fi

if [[ ! -e \
    "$STAGE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service"
]]; then
    pass "Staged live SSH autostart is disabled"
else
    fail "Staged live SSH autostart is enabled"
fi

echo
echo "========================================"
echo "ISO preflight complete"
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"
echo "========================================"

if (( ERRORS > 0 )); then
    exit 1
fi
