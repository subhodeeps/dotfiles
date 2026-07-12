#!/bin/bash

# Define the backup directory
BACKUP_DIR=~/dotfiles
mkdir -p "$BACKUP_DIR"

# --- HELPER FUNCTIONS ---
backup_file() {
    local src="$1"
    local dest="$2"
    local name="${3:-$(basename "$src")}"
    
    if [ -f "$src" ]; then
        # Ensure destination directory exists
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
        echo "✓ Copied $name"
    else
        echo "! Skipping $name (File not found)"
    fi
}

backup_dir() {
    local src="$1"
    local dest="$2"
    local name="${3:-$(basename "$src")}"
    
    if [ -d "$src" ]; then
        # Remove old directory in backup to prevent nested copies
        rm -rf "$dest/$(basename "$src")"
        cp -r "$src" "$dest"
        echo "✓ Copied $name config"
    else
        echo "! Skipping $name (Directory not found)"
    fi
}
# ------------------------

echo "Starting User Dotfiles Backup..."

# 1. Zsh
backup_file ~/.zshrc "$BACKUP_DIR/" ".zshrc"

# 2. Starship
backup_file ~/.config/starship.toml "$BACKUP_DIR/" "starship.toml"

# 3. Kitty 
# (We remove the old folder first so 'cp' doesn't accidentally nest folders inside each other)
backup_dir ~/.config/kitty "$BACKUP_DIR" "kitty"

# 4. Fastfetch
backup_dir ~/.config/fastfetch "$BACKUP_DIR" "fastfetch"

# 5. KDE Global Shortcuts (for Krohnkite)
backup_file ~/.config/kglobalshortcutsrc "$BACKUP_DIR/" "kglobalshortcutsrc (Krohnkite shortcuts)"

echo "User Dotfiles Backup complete! Ready to commit and push."

# Define the new system configs directory
SYS_DIR="$BACKUP_DIR/system-configs"

# Wipe the old system config backup folder and recreate it for a clean slate
rm -rf "$SYS_DIR"
mkdir -p "$SYS_DIR"

echo "Starting system config backup..."

# 6. KDE Window Manager (Krohnkite rules)
backup_file ~/.config/kwinrc "$BACKUP_DIR/" "kwinrc"

# 7. Optimus Manager
backup_file /etc/optimus-manager/optimus-manager.conf "$SYS_DIR/" "optimus-manager.conf"

# 8. Boot & Filesystem Mounts
backup_file /etc/fstab "$SYS_DIR/" "fstab"
backup_file /etc/default/grub "$SYS_DIR/" "grub"
backup_file /etc/mkinitcpio.conf "$SYS_DIR/" "mkinitcpio.conf"

# 9. Installed Package List
if command -v pacman > /dev/null; then
    pacman -Qqe > "$SYS_DIR/installed-packages.txt"
    echo "✓ Generated installed-packages.txt"
else
    echo "! Skipping installed-packages.txt (pacman not found)"
fi

# 10. Zram Configuration (Memory Compression)
backup_file /etc/systemd/zram-generator.conf "$SYS_DIR/" "zram-generator.conf"

# 11. Kernel Memory Tweaks (Swappiness for Zram)
backup_file /etc/sysctl.d/99-vm-zram-parameters.conf "$SYS_DIR/" "99-vm-zram-parameters.conf"

# 12. Throttled (CPU/Undervolt Power Management)
backup_file /etc/throttled.conf "$SYS_DIR/" "throttled.conf"

# 13. Pacman Configuration
backup_file /etc/pacman.conf "$SYS_DIR/" "pacman.conf"

# 14. Thinkfan (Fan Control)
backup_file /etc/thinkfan.conf "$SYS_DIR/" "thinkfan.conf"

# 15. Package Manifests
echo "Generating package lists..."

# Official Repo Packages
if command -v pacman > /dev/null; then
    pacman -Qqe > "$SYS_DIR/pkglist-official.txt"
    echo "✓ Generated pkglist-official.txt"
fi

# AUR Packages (requires expac)
if command -v expac > /dev/null; then
    expac -Qqe "$(pacman -Qmq)" > "$SYS_DIR/pkglist-aur.txt"
    echo "✓ Generated pkglist-aur.txt"
else
    echo "! Skipping AUR list (expac not installed)"
fi

# 16. Python Environments Manifest
ENV_DIR="$SYS_DIR/python-envs"
mkdir -p "$ENV_DIR"

echo "Backing up Python environments..."

echo "  Exporting Global Python environment..."

# Capture user-level global packages (~/.local/)
if command -v python3 > /dev/null; then
    python3 --version > "$ENV_DIR/global-version.txt"
    # Suppress warnings about PEP 668 and capture frozen list
    python3 -m pip list --user --format=freeze > "$ENV_DIR/global-requirements.txt" 2>/dev/null
    echo "  ✓ Captured global pip packages"
fi

# Capture pipx applications 
if command -v pipx > /dev/null; then
    pipx list --short > "$ENV_DIR/pipx-apps.txt"
    echo "  ✓ Captured pipx applications"
fi

# Find all venv folders 
find ~ -maxdepth 3 -name "pyvenv.cfg" -exec dirname {} \; | while read -r venv_path; do
    # Gets the name of the project folder containing the venv instead of just 'venv'
    env_name=$(basename "$(dirname "$venv_path")") 
    
    echo "  Exporting $env_name..."
    # Capture python version and pip list
    "$venv_path/bin/python" --version > "$ENV_DIR/$env_name-version.txt"
    "$venv_path/bin/pip" list --format=freeze > "$ENV_DIR/$env_name-requirements.txt"
done

# If we use Conda
if command -v conda > /dev/null; then
    conda env list | cut -d' ' -f1 | grep -v '^#' | while read -r env_name; do
        conda list -n "$env_name" --export > "$ENV_DIR/conda-$env_name.txt"
        echo "  ✓ Captured conda env: $env_name"
    done
fi

# 17. Global Julia Environment
JULIA_GLOBAL_DIR="$SYS_DIR/julia-global"
mkdir -p "$JULIA_GLOBAL_DIR"

echo "Backing up Global Julia environment..."

# Julia stores global packages in ~/.julia/environments/v1.x/
# Get the highest version number folder to prevent multi-line errors
JULIA_VERSION_DIR=$(find ~/.julia/environments -maxdepth 1 -type d -name "v*" 2>/dev/null | sort -V | tail -n 1)

if [ -n "$JULIA_VERSION_DIR" ] && [ -d "$JULIA_VERSION_DIR" ]; then
    backup_file "$JULIA_VERSION_DIR/Project.toml" "$JULIA_GLOBAL_DIR/" "Julia Project.toml"
    
    if [ -f "$JULIA_VERSION_DIR/Manifest.toml" ]; then
        backup_file "$JULIA_VERSION_DIR/Manifest.toml" "$JULIA_GLOBAL_DIR/" "Julia Manifest.toml"
    fi
else
    echo "! Skipping Julia: No global environment found in ~/.julia/environments"
fi

# 18. Default Applications (mimeapps.list)
backup_file ~/.config/mimeapps.list "$BACKUP_DIR/" "mimeapps.list"

echo "All backups completed successfully!"