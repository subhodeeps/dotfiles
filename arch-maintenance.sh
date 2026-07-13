#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Arch Linux Maintenance Utility${NC}"
echo -e "${YELLOW}Run this script as a normal user (it will invoke sudo when necessary).${NC}"
echo "------------------------------------------------------"

sudo -v

function clean_pkg_cache() {
    echo -e "\n${YELLOW}=== Cleaning Package Cache ===${NC}"
    
    # Clean up incomplete pacman downloads (wrapped in bash -c to ensure root wildcard expansion)
    echo "Cleaning up incomplete temporary download files..."
    sudo bash -c 'rm -rf /var/cache/pacman/pkg/download-*'
    
    if ! command -v paccache &> /dev/null; then
        echo -e "${RED}paccache not found. Installing pacman-contrib...${NC}"
        sudo pacman -S --noconfirm pacman-contrib
    fi

    echo "1) Removing cached versions of UNINSTALLED packages (keeping 0)..."
    sudo paccache -ruk0

    echo "2) Removing old cached versions of INSTALLED packages (keeping default 3)..."
    sudo paccache -r

    echo -ne "${YELLOW}Do you also want an aggressive clean with 'pacman -Sc'? (y/N): ${NC}"
    read confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo pacman -Sc
    fi
    echo -e "${GREEN}Package cache cleaned.${NC}\n"
}

function clean_aur_cache() {
    echo -e "\n${YELLOW}=== Cleaning AUR Cache ===${NC}"
    if command -v yay &> /dev/null; then
        echo "Cleaning yay cache..."
        yay -Sc --noconfirm
    elif command -v paru &> /dev/null; then
        echo "Cleaning paru cache..."
        paru -Sc --noconfirm
    else
        echo "No standard AUR helper (yay/paru) detected in PATH."
    fi
    echo -e "${GREEN}AUR cache cleanup complete.${NC}\n"
}

function clean_journal() {
    echo -e "\n${YELLOW}=== Cleaning Systemd Journal ===${NC}"
    echo "Rotating active journal files..."
    sudo journalctl --rotate

    echo "Vacuuming journal..."
    sudo journalctl --vacuum-size=100M
    sudo journalctl --vacuum-time=2weeks
    echo -e "${GREEN}Journal cleaned to max 100M or 2 weeks.${NC}\n"
}

function clean_coredumps() {
    echo -e "\n${YELLOW}=== Cleaning System Coredumps ===${NC}"
    echo "Removing crash dumps from /var/lib/systemd/coredump/..."
    sudo rm -rf /var/lib/systemd/coredump/*
    echo -e "${GREEN}Coredumps removed.${NC}\n"
}

function remove_orphans() {
    echo -e "\n${YELLOW}=== Removing Unused Packages (Orphans) ===${NC}"
    ORPHANS=$(pacman -Qdtq)
    
    if [[ -z "$ORPHANS" ]]; then
        echo -e "${GREEN}No orphaned packages found.${NC}\n"
    else
        echo "Found the following orphans:"
        echo -e "${RED}$ORPHANS${NC}"
        echo -ne "${YELLOW}Do you want to remove these packages and their unneeded dependencies (-Rns)? (y/N): ${NC}"
        read confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            sudo pacman -Rns $ORPHANS
            echo -e "${GREEN}Orphans removed.${NC}\n"
        else
            echo "Skipping orphan removal."
        fi
    fi
}

function clean_thumbnails() {
    echo -e "\n${YELLOW}=== Cleaning Thumbnail Cache ===${NC}"
    if [ -d "$HOME/.cache/thumbnails" ]; then
        rm -rf "$HOME/.cache/thumbnails/"*
        echo -e "${GREEN}Thumbnail cache cleared.${NC}\n"
    else
        echo -e "${GREEN}No thumbnail cache found.${NC}\n"
    fi
}

function clean_flatpak() {
    echo -e "\n${YELLOW}=== Cleaning Flatpak Runtimes ===${NC}"
    if command -v flatpak &> /dev/null; then
        echo "Removing unused Flatpak runtimes and extensions..."
        flatpak uninstall --unused -y
        echo -e "${GREEN}Flatpak cleanup complete.${NC}\n"
    else
        echo -e "${GREEN}Flatpak is not installed. Skipping.${NC}\n"
    fi
}

function find_and_remove() {
    echo -e "\n${YELLOW}=== Find and Remove (rmlint) ===${NC}"
    if ! command -v rmlint &> /dev/null; then
        echo -ne "${YELLOW}rmlint is not installed (it is an AUR package). Install it now? (y/N): ${NC}"
        read confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            if command -v yay &> /dev/null; then
                yay -S --noconfirm rmlint
            elif command -v paru &> /dev/null; then
                paru -S --noconfirm rmlint
            else
                echo -e "${RED}No AUR helper (yay/paru) found. Please install rmlint manually from the AUR.${NC}"
                return
            fi
        else
            echo "Skipping rmlint execution."
            return
        fi
        
        # Verify installation succeeded before proceeding
        if ! command -v rmlint &> /dev/null; then
            echo -e "${RED}Installation failed. Aborting rmlint scan.${NC}"
            return
        fi
    fi

    echo "Running rmlint on your home directory..."
    rmlint ~/
    echo -e "${GREEN}rmlint scan complete. Review 'rmlint.sh' before executing it.${NC}\n"
}

while true; do
    echo -e "${GREEN}Select an operation:${NC}"
    echo "1) Clean Package Cache (pacman)"
    echo "2) Clean AUR Cache (yay/paru)"
    echo "3) Clean Systemd Journal"
    echo "4) Clean System Coredumps"
    echo "5) Remove Unused Packages (Orphans)"
    echo "6) Clean Thumbnail Cache"
    echo "7) Clean Flatpak Runtimes"
    echo "8) Find Duplicates/Broken Links (rmlint)"
    echo -e "${YELLOW}9) Run ALL SAFE Operations (1, 2, 3, 4, 5, 6, 7)${NC}"
    echo -e "${RED}0) Exit${NC}"
    
    echo -ne "\n${GREEN}Enter choice [0-9]: ${NC}"
    read choice

    case $choice in
        1) clean_pkg_cache ;;
        2) clean_aur_cache ;;
        3) clean_journal ;;
        4) clean_coredumps ;;
        5) remove_orphans ;;
        6) clean_thumbnails ;;
        7) clean_flatpak ;;
        8) find_and_remove ;;
        9) 
            clean_pkg_cache
            clean_aur_cache
            clean_journal
            clean_coredumps
            remove_orphans
            clean_thumbnails
            clean_flatpak
            ;;
        0) 
            echo -e "${GREEN}Exiting.${NC}"
            exit 0 
            ;;
        *) 
            echo -e "${RED}Invalid option.${NC}" 
            ;;
    esac
done