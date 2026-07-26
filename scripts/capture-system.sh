#!/usr/bin/env bash

set -e

OUTPUT=~/NomadOS/inventory

mkdir -p "$OUTPUT"

echo "Capturing installed packages..."
pacman -Qqe > "$OUTPUT/packages.txt"

echo "Capturing enabled services..."
systemctl list-unit-files --state=enabled > "$OUTPUT/services.txt"

echo "Capturing loaded kernel modules..."
lsmod > "$OUTPUT/modules.txt"

echo "Capturing disks..."
lsblk -f > "$OUTPUT/disks.txt"

echo "Capturing mounts..."
findmnt > "$OUTPUT/mounts.txt"

echo "Capturing CPU..."
lscpu > "$OUTPUT/cpu.txt"

echo "Capturing memory..."
free -h > "$OUTPUT/memory.txt"

echo "Capturing PCI devices..."
lspci -nnk > "$OUTPUT/pci.txt"

echo "Capturing USB devices..."
lsusb > "$OUTPUT/usb.txt"

echo "Capturing safe environment summary..."
{
    printf 'SHELL=%s
' "${SHELL:-}"
    printf 'LANG=%s
' "${LANG:-}"
    printf 'LC_ALL=%s
' "${LC_ALL:-}"
    printf 'TERM=%s
' "${TERM:-}"
    printf 'XDG_CURRENT_DESKTOP=%s
' "${XDG_CURRENT_DESKTOP:-}"
    printf 'XDG_SESSION_DESKTOP=%s
' "${XDG_SESSION_DESKTOP:-}"
    printf 'XDG_SESSION_TYPE=%s
' "${XDG_SESSION_TYPE:-}"
} > "$OUTPUT/environment.txt"

echo "Done."
