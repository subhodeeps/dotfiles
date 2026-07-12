#!/bin/bash

# Define the backup directory
BACKUP_DIR=~/dotfiles

echo "Starting terminal backup..."

# 1. Zsh
cp ~/.zshrc "$BACKUP_DIR/"
echo "✓ Copied .zshrc"

# 2. Starship
cp ~/.config/starship.toml "$BACKUP_DIR/"
echo "✓ Copied starship.toml"

# 3. Kitty 
# (We remove the old folder first so 'cp' doesn't accidentally nest folders inside each other)
rm -rf "$BACKUP_DIR/kitty"
cp -r ~/.config/kitty "$BACKUP_DIR/"
echo "✓ Copied Kitty config"

# 4. Fastfetch
rm -rf "$BACKUP_DIR/fastfetch"
cp -r ~/.config/fastfetch "$BACKUP_DIR/"
echo "✓ Copied Fastfetch config"

# 5. KDE Global Shortcuts (for Krohnkite)
cp ~/.config/kglobalshortcutsrc "$BACKUP_DIR/"
echo "✓ Copied kglobalshortcutsrc (Krohnkite shortcuts)"

echo "User Dotfiles Backup complete! Ready to commit and push."

# Define the new system configs directory
SYS_DIR="$BACKUP_DIR/system-configs"
mkdir -p "$SYS_DIR"

echo "Starting system config backup..."

# 6. KDE Window Manager (Krohnkite rules)
cp ~/.config/kwinrc "$BACKUP_DIR/"
echo "✓ Copied kwinrc"

# 7. Optimus Manager
cp /etc/optimus-manager/optimus-manager.conf "$SYS_DIR/"
echo "✓ Copied optimus-manager.conf"

# 8. Boot & Filesystem Mounts
cp /etc/fstab "$SYS_DIR/"
cp /etc/default/grub "$SYS_DIR/"
cp /etc/mkinitcpio.conf "$SYS_DIR/"
echo "✓ Copied fstab, grub, and mkinitcpio.conf"

# 9. Installed Package List
pacman -Qqe > "$SYS_DIR/installed-packages.txt"
echo "✓ Generated installed-packages.txt"

# 10. Zram Configuration (Memory Compression)
cp /etc/systemd/zram-generator.conf "$SYS_DIR/"
echo "✓ Copied zram-generator.conf"

# 11. Kernel Memory Tweaks (Swappiness for Zram)
cp /etc/sysctl.d/99-vm-zram-parameters.conf "$SYS_DIR/"
echo "✓ Copied 99-vm-zram-parameters.conf"

# 12. Throttled (CPU/Undervolt Power Management)
cp /etc/throttled.conf "$SYS_DIR/"
echo "✓ Copied throttled.conf"

# 13. Pacman Configuration
cp /etc/pacman.conf "$SYS_DIR/"
echo "✓ Copied pacman.conf"

# 14. Thinkfan (Fan Control)
cp /etc/thinkfan.conf "$SYS_DIR/"
echo "✓ Copied thinkfan.conf"

# 15. Package Manifests
echo "Generating package lists..."

# Official Repo Packages
pacman -Qqe > "$SYS_DIR/pkglist-official.txt"

# AUR Packages (requires expac)
if command -v expac > /dev/null; then
    expac -Qqe "$(pacman -Qmq)" > "$SYS_DIR/pkglist-aur.txt"
else
    echo "! Skipping AUR list (expac not installed)"
fi

echo "✓ Package lists generated in $SYS_DIR"

# 16. Python Environments Manifest
ENV_DIR="$SYS_DIR/python-envs"
mkdir -p "$ENV_DIR"

echo "Backing up Python environments..."

# Find all venv folders 
find ~ -maxdepth 3 -name "pyvenv.cfg" -exec dirname {} \; | while read -r venv_path; do
    env_name=$(basename "$venv_path")
    echo "  Exporting $env_name..."
    # Capture python version and pip list
    "$venv_path/bin/python" --version > "$ENV_DIR/$env_name-version.txt"
    "$venv_path/bin/pip" list --format=freeze > "$ENV_DIR/$env_name-requirements.txt"
done

# If we use Conda
if command -v conda > /dev/null; then
    conda env list | cut -d' ' -f1 | grep -v '^#' | while read -r env_name; do
        conda list -n "$env_name" --export > "$ENV_DIR/conda-$env_name.txt"
    done
fi

# 17. Global Julia Environment
JULIA_GLOBAL_DIR="$SYS_DIR/julia-global"
mkdir -p "$JULIA_GLOBAL_DIR"

echo "Backing up Global Julia environment..."

# Julia stores global packages in ~/.julia/environments/v1.x/
# We copy the manifest and project files so we can instantiate the global environment anywhere
JULIA_VERSION_DIR=$(find ~/.julia/environments -maxdepth 1 -name "v*")

if [ -d "$JULIA_VERSION_DIR" ]; then
    cp "$JULIA_VERSION_DIR/Project.toml" "$JULIA_GLOBAL_DIR/"
    if [ -f "$JULIA_VERSION_DIR/Manifest.toml" ]; then
        cp "$JULIA_VERSION_DIR/Manifest.toml" "$JULIA_GLOBAL_DIR/"
    fi
    echo "  ✓ Captured global Julia environment (Project.toml + Manifest.toml)"
else
    echo "! Skipping Julia: No global environment found in ~/.julia/environments"
fi

echo "All backups completed successfully!"