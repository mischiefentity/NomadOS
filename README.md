# NomadOS

NomadOS is a custom Arch Linux-based operating system for the Ultimate Nomad Computer Science Laboratory.

## Goal

The goal of this project is to reproduce the fully configured NomadOS virtual machine on physical hardware with minimal manual setup.

The virtual machine serves as the golden master development environment. Its packages, services, desktop configuration, themes, scripts, and system settings will be stored in this repository and used to build a custom Arch Linux ISO.

## Planned Features

- Arch Linux base
- AwesomeWM desktop environment
- Kitty terminal
- Neovim development environment
- Custom SDDM login theme
- Custom wallpapers, icons, fonts, and branding
- Local AI tools
- Networking and cybersecurity tools
- RF and satellite tools
- Robotics and drone support
- Portable laboratory utilities
- Automated installation
- Custom bootable ISO

## Repository Structure

- `archiso/` — ArchISO build profile
- `assets/` — wallpapers, fonts, icons, and themes
- `configs/` — application and desktop configuration
- `docs/` — project documentation
- `dotfiles/` — user configuration files
- `installer/` — installation scripts
- `inventory/` — captured VM system information
- `iso/` — ISO-related files
- `packages/` — package lists
- `scripts/` — maintenance and automation scripts
- `system/` — system-wide configuration
- `work/` — temporary ArchISO build files
- `out/` — generated ISO output

## Development Model

1. Configure and test NomadOS inside the virtual machine.
2. Capture packages, services, and configuration.
3. Store all reproducible configuration in Git.
4. Automate installation and configuration.
5. Build and test the custom ISO.
6. Install NomadOS on physical hardware.
