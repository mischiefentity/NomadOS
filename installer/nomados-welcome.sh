#!/usr/bin/env bash
set -euo pipefail

while true; do
    clear

    cat <<'EOF'
====================================================
                 Welcome to NomadOS
====================================================

1) Install NomadOS
2) Continue using the live environment
3) Open a terminal shell

The installer is guided, but the selected target disk
will be completely erased after explicit confirmation.

EOF

    read -rp "Select an option [1-3]: " choice

    case "$choice" in
        1)
            exec sudo /usr/local/bin/nomados-install
            ;;
        2)
            echo
            echo "The live environment is ready."
            echo "Run 'nomados-welcome' from Kitty to reopen this menu."
            sleep 2
            exit 0
            ;;
        3)
            exec /usr/bin/zsh
            ;;
        *)
            echo "Enter 1, 2, or 3."
            sleep 1
            ;;
    esac
done
