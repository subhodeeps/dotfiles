#!/bin/bash

# Define the backup directory
BACKUP_DIR=~/dotfiles
mkdir -p "$BACKUP_DIR"

# Scratch/staging directory — kept out of git via .gitignore (see below)
TMP_DIR="$BACKUP_DIR/tmp"
mkdir -p "$TMP_DIR"

# --- HELPER FUNCTIONS FOR USER FILES ---
backup_file() {
    local src="$1"
    local dest="$2"
    local name="${3:-$(basename "$src")}"
    
    if [ -f "$src" ]; then
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
        rm -rf "$dest/$(basename "$src")"
        cp -r "$src" "$dest"
        echo "✓ Copied $name config"
    else
        echo "! Skipping $name (Directory not found)"
    fi
}

# --- HELPER FUNCTIONS FOR SYSTEM FILES (Requires sudo) ---
sys_backup_file() {
    local src="$1"
    local dest="$2"
    local name="${3:-$(basename "$src")}"
    
    if sudo test -f "$src"; then
        mkdir -p "$(dirname "$dest")"
        sudo cp "$src" "$dest"
        echo "✓ Copied $name"
    else
        echo "! Skipping $name (File not found)"
    fi
}

sys_backup_dir() {
    local src="$1"
    local dest="$2"
    local name="${3:-$(basename "$src")}"
    
    if sudo test -d "$src"; then
        rm -rf "$dest/$(basename "$src")"
        sudo cp -r "$src" "$dest"
        echo "✓ Copied $name config"
    else
        echo "! Skipping $name (Directory not found)"
    fi
}
# ------------------------

echo "Starting User Dotfiles Backup..."

# Zsh
backup_file ~/.zshrc "$BACKUP_DIR/" ".zshrc"

# Starship
backup_file ~/.config/starship.toml "$BACKUP_DIR/" "starship.toml"

# Kitty 
backup_dir ~/.config/kitty "$BACKUP_DIR" "kitty"

# Fastfetch
backup_dir ~/.config/fastfetch "$BACKUP_DIR" "fastfetch"

# KDE Global Shortcuts (for Krohnkite)
backup_file ~/.config/kglobalshortcutsrc "$BACKUP_DIR/" "kglobalshortcutsrc (Krohnkite shortcuts)"

# KDE Window Manager (Krohnkite rules)
backup_file ~/.config/kwinrc "$BACKUP_DIR/" "kwinrc"

# Pet (Command Snippet Manager) — config.toml + snippet.toml 
backup_dir ~/.config/pet "$BACKUP_DIR" "pet (config & snippets)"

# User Scripts Directory
backup_dir ~/scripts "$BACKUP_DIR" "scripts"

# VS Code
echo "Backing up VS Code..."

backup_file ~/.config/Code/User/settings.json "$BACKUP_DIR/vscode/settings.json" "VS Code settings"
backup_file ~/.config/Code/User/keybindings.json "$BACKUP_DIR/vscode/keybindings.json" "VS Code keybindings"

# Installed extensions
if command -v code >/dev/null; then
    # Create the directory explicitly just in case it doesn't exist yet
    mkdir -p "$BACKUP_DIR/vscode"
    code --list-extensions | sort > "$BACKUP_DIR/vscode/extensions.txt"
    echo "✓ Generated extensions.txt"
else
    echo "! Skipping VS Code extensions (code command not found)"
fi

# Zotero
echo "Backing up Zotero configs and extensions list..."
ZOTERO_DIR="$BACKUP_DIR/zotero"
mkdir -p "$ZOTERO_DIR"

# Find the default profile directory (handles random string profile names)
ZOTERO_PROFILE=$(find ~/.zotero/zotero -maxdepth 1 -type d -name "*.default*" | head -n 1)

if [ -n "$ZOTERO_PROFILE" ] && [ -d "$ZOTERO_PROFILE" ]; then
    # Back up main preferences
    backup_file "$ZOTERO_PROFILE/prefs.js" "$ZOTERO_DIR/" "Zotero prefs.js"
    
    # Generate list of installed extensions
    if [ -d "$ZOTERO_PROFILE/extensions" ]; then
        ls -1 "$ZOTERO_PROFILE/extensions" > "$ZOTERO_DIR/extensions.txt"
        echo "✓ Generated Zotero extensions.txt"
    else
        echo "  - No Zotero extensions found"
    fi
else
    echo "! Skipping Zotero (No profile found in ~/.zotero/zotero)"
fi


echo "User Dotfiles Backup complete! Ready to commit and push."

# Define the new system configs directory
SYS_DIR="$BACKUP_DIR/system-configs"

# Wipe the old system config backup folder and recreate it for a clean slate
rm -rf "$SYS_DIR"
mkdir -p "$SYS_DIR"

# README located in: $TMP_DIR/README_SYS.md

README_TEMPLATE="$TMP_DIR/README_SYS.md"


cp "$README_TEMPLATE" "$SYS_DIR/README.md"
echo "✓ Copied system-configs/README.md from tmp/readme.md"

echo "----------------------------------------------------"
echo "Requesting sudo password to backup system configs..."
sudo -v
echo "----------------------------------------------------"

echo "Starting system config backup..."

# Optimus Manager
sys_backup_file /etc/optimus-manager/optimus-manager.conf "$SYS_DIR/" "optimus-manager.conf"

# Boot & Filesystem Mounts
sys_backup_file /etc/fstab "$SYS_DIR/" "fstab"
sys_backup_file /etc/mkinitcpio.conf "$SYS_DIR/" "mkinitcpio.conf"

# Back up GRUB (Fallback)
sys_backup_file /etc/default/grub "$SYS_DIR/" "grub (fallback)"

# Verify and back up systemd-boot (Primary)
if command -v bootctl > /dev/null; then
    ESP_PATH=$(bootctl -p 2>/dev/null)
    
    if [ -n "$ESP_PATH" ] && sudo test -d "$ESP_PATH/loader"; then
        sys_backup_dir "$ESP_PATH/loader" "$SYS_DIR" "systemd-boot loader"
        
        # Exclude random-seed from backup
        sudo rm -f "$SYS_DIR/loader/random-seed"
    else
        echo "! Skipping systemd-boot (loader directory not found in $ESP_PATH)"
    fi
fi 

# Installed Package List
if command -v pacman > /dev/null; then
    pacman -Qqe > "$SYS_DIR/installed-packages.txt"
    echo "✓ Generated installed-packages.txt"
else
    echo "! Skipping installed-packages.txt (pacman not found)"
fi

# Zram Configuration (Memory Compression)
sys_backup_file /etc/systemd/zram-generator.conf "$SYS_DIR/" "zram-generator.conf"

# Kernel Memory Tweaks (Swappiness for Zram)
sys_backup_file /etc/sysctl.d/99-vm-zram-parameters.conf "$SYS_DIR/" "99-vm-zram-parameters.conf"

# Throttled (CPU/Undervolt Power Management)
sys_backup_file /etc/throttled.conf "$SYS_DIR/" "throttled.conf"

# Pacman Configuration
sys_backup_file /etc/pacman.conf "$SYS_DIR/" "pacman.conf"

# Pacman Hooks (This captures 99-sync-kernel.hook and any others)
sys_backup_dir /etc/pacman.d/hooks "$SYS_DIR" "pacman hooks"

# Thinkfan (Fan Control)
sys_backup_file /etc/thinkfan.conf "$SYS_DIR/" "thinkfan.conf"

# Package Manifests
echo "Generating package lists..."

# Official Repo Packages
if command -v pacman > /dev/null; then
    pacman -Qqe > "$SYS_DIR/pkglist-official.txt"
    echo "✓ Generated pkglist-official.txt"
fi

# AUR Packages (requires expac)
if command -v expac > /dev/null; then
    expac -Qe "$(pacman -Qmq)" > "$SYS_DIR/pkglist-aur.txt" 2>/dev/null
    echo "✓ Generated pkglist-aur.txt"
else
    echo "! Skipping AUR list (expac not installed)"
fi

# Python Environments Manifest
ENV_DIR="$SYS_DIR/python-envs"
mkdir -p "$ENV_DIR"

echo "Backing up Python environments..."

# Global Python (Pacman-installed)
pacman -Qqe | grep "^python-" > "$ENV_DIR/global-pacman-python.txt"
echo "  ✓ Captured global Pacman-installed Python packages"

# User-level global packages (~/.local/)
if command -v python3 > /dev/null; then
    USER_PIP_PKGS=$(python3 -m pip list --user --format=freeze 2>/dev/null)
    if [ -n "$USER_PIP_PKGS" ]; then
        python3 --version > "$ENV_DIR/global-version.txt"
        echo "$USER_PIP_PKGS" > "$ENV_DIR/global-requirements.txt"
        echo "  ✓ Captured global pip packages"
    else
        echo "  - No user-level pip packages found (skipping global-requirements.txt)"
    fi
fi

# Capture pipx applications
if command -v pipx > /dev/null; then
    PIPX_LIST=$(pipx list --short)
    if [ -n "$PIPX_LIST" ]; then
        echo "$PIPX_LIST" > "$ENV_DIR/pipx-apps.txt"
        echo "  ✓ Captured pipx applications"
    else
        echo "  - No pipx applications found"
    fi
fi

# Find all venv folders 
find ~ -maxdepth 3 -name "pyvenv.cfg" -exec dirname {} \; | while read -r venv_path; do
    parent_dir=$(basename "$(dirname "$venv_path")")
    venv_name=$(basename "$venv_path")
    
    if [[ "$parent_dir" == "$HOME" || "$parent_dir" == "/" ]]; then
        env_label="$venv_name"
    else
        env_label="${parent_dir}_${venv_name}"
    fi
    
    echo "  Exporting $env_label..."
    
    if [ -f "$venv_path/bin/python" ]; then
        "$venv_path/bin/python" --version > "$ENV_DIR/$env_label-version.txt"
        "$venv_path/bin/pip" list --format=freeze > "$ENV_DIR/$env_label-requirements.txt"
    else
        echo "  ! Skipping $env_label (No python executable found)"
    fi
done

# Conda Environments
if command -v conda > /dev/null; then
    conda env list | cut -d' ' -f1 | grep -v '^#' | while read -r env_name; do
        conda list -n "$env_name" --export > "$ENV_DIR/conda-$env_name.txt"
        echo "  ✓ Captured conda env: $env_name"
    done
fi

# Global Julia Environment
JULIA_GLOBAL_DIR="$SYS_DIR/julia-global"
mkdir -p "$JULIA_GLOBAL_DIR"

echo "Backing up Global Julia environment..."

JULIA_VERSION_DIR=$(find ~/.julia/environments -maxdepth 1 -type d -name "v*" 2>/dev/null | sort -V | tail -n 1)

if [ -n "$JULIA_VERSION_DIR" ] && [ -d "$JULIA_VERSION_DIR" ]; then
    backup_file "$JULIA_VERSION_DIR/Project.toml" "$JULIA_GLOBAL_DIR/" "Julia Project.toml"
    
    if [ -f "$JULIA_VERSION_DIR/Manifest.toml" ]; then
        backup_file "$JULIA_VERSION_DIR/Manifest.toml" "$JULIA_GLOBAL_DIR/" "Julia Manifest.toml"
    fi
else
    echo "! Skipping Julia: No global environment found in ~/.julia/environments"
fi

# Default Applications (mimeapps.list)
backup_file ~/.config/mimeapps.list "$BACKUP_DIR/" "mimeapps.list"

# Fix ownership for files copied via sudo to ensure standard user ownership
sudo chown -R "$USER:$USER" "$SYS_DIR"

# Make sure the scratch/staging tmp/ folder never gets committed to the dotfiles repo
GITIGNORE="$BACKUP_DIR/.gitignore"
touch "$GITIGNORE"
if ! grep -qxF "tmp/" "$GITIGNORE"; then
    echo "tmp/" >> "$GITIGNORE"
    echo "✓ Added tmp/ to .gitignore"
fi

echo "All backups completed successfully!"