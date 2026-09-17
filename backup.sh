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
        mkdir -p "$dest"
        rm -rf "$dest/$(basename "$src")"
        cp -r "$src" "$dest"
        # Remove nested .git folders, otherwise git stores them as empty gitlinks
        find "$dest/$(basename "$src")" -name .git -prune -exec rm -rf {} + 2>/dev/null
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
# Checks the native install first, then the Flathub version
ZOTERO_PROFILE=$(find ~/.zotero/zotero ~/.var/app/org.zotero.Zotero/.zotero/zotero \
    -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1)

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
    echo "! Skipping Zotero (No profile found)"
fi

# Python venv specs (managed by ~/venvs/upgrade-numerics.sh)
echo "Backing up venv specs..."
VENV_ROOT=~/venvs
VENV_SPEC_DIR="$BACKUP_DIR/venvs"

if [ -d "$VENV_ROOT" ]; then
    # Wipe the old copy so removed envs don't linger
    rm -rf "$VENV_SPEC_DIR"
    mkdir -p "$VENV_SPEC_DIR"

    backup_file "$VENV_ROOT/upgrade-numerics.sh" "$VENV_SPEC_DIR/" "upgrade-numerics.sh"

    # Each <env>.lock folder: requirements.in/.txt, uv.env, smoke.py (backups/ stays local)
    for lock_dir in "$VENV_ROOT"/*.lock; do
        [ -d "$lock_dir" ] || continue
        lock_name=$(basename "$lock_dir")
        mkdir -p "$VENV_SPEC_DIR/$lock_name"
        for f in requirements.in requirements.txt uv.env smoke.py; do
            if [ -f "$lock_dir/$f" ]; then
                cp "$lock_dir/$f" "$VENV_SPEC_DIR/$lock_name/"
            fi
        done
        echo "✓ Copied $lock_name specs"
    done
else
    echo "! Skipping venv specs ($VENV_ROOT not found)"
fi


echo "User Dotfiles Backup complete! Ready to commit and push."

echo "----------------------------------------------------"
echo "Requesting sudo password to backup system configs..."
sudo -v
echo "----------------------------------------------------"

# Define the new system configs directory
SYS_DIR="$BACKUP_DIR/system-configs"

# Wipe the old system config backup folder and recreate it for a clean slate
# (sudo, because an interrupted earlier run can leave root-owned files behind)
sudo rm -rf "$SYS_DIR"
mkdir -p "$SYS_DIR"

# README template: templates/ is tracked by git; tmp/ is only a fallback
README_TEMPLATE="$BACKUP_DIR/templates/README_SYS.md"
[ -f "$README_TEMPLATE" ] || README_TEMPLATE="$TMP_DIR/README_SYS.md"

if [ -f "$README_TEMPLATE" ]; then
    cp "$README_TEMPLATE" "$SYS_DIR/README.md"
    echo "✓ Copied system-configs/README.md from ${README_TEMPLATE#"$BACKUP_DIR"/}"
else
    echo "! Skipping system-configs/README.md (README_SYS.md not found in templates/ or tmp/)"
fi

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
    # sudo: the ESP is often not readable by normal users
    ESP_PATH=$(sudo bootctl -p 2>/dev/null)
    
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

if command -v pacman > /dev/null; then
    # Official Repo Packages (native only, so the list restores with pacman -S)
    pacman -Qqen > "$SYS_DIR/pkglist-official.txt"
    echo "✓ Generated pkglist-official.txt"

    # AUR / foreign packages
    pacman -Qqem > "$SYS_DIR/pkglist-aur.txt"
    echo "✓ Generated pkglist-aur.txt"
fi

# Flatpak Apps (Flathub and any other remotes)
if command -v flatpak > /dev/null; then
    FLATPAK_DIR="$SYS_DIR/flatpak"
    mkdir -p "$FLATPAK_DIR"

    echo "Backing up Flatpak apps..."

    for scope in system user; do
        # App ID + origin remote; runtimes are pulled in again on reinstall
        flatpak list --$scope --app --columns=application,origin > "$FLATPAK_DIR/apps-$scope.txt" 2>/dev/null
        flatpak remotes --$scope --columns=name,url > "$FLATPAK_DIR/remotes-$scope.txt" 2>/dev/null

        if [ -s "$FLATPAK_DIR/apps-$scope.txt" ]; then
            echo "  ✓ Captured $scope Flatpak apps"
        else
            rm -f "$FLATPAK_DIR/apps-$scope.txt"
            echo "  - No $scope Flatpak apps found"
        fi
        [ -s "$FLATPAK_DIR/remotes-$scope.txt" ] || rm -f "$FLATPAK_DIR/remotes-$scope.txt"
    done

    # Permission overrides (Flatseal / flatpak override)
    backup_dir ~/.local/share/flatpak/overrides "$FLATPAK_DIR/user" "Flatpak user overrides"
    backup_dir /var/lib/flatpak/overrides "$FLATPAK_DIR/system" "Flatpak system overrides"
else
    echo "! Skipping Flatpak (flatpak not installed)"
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
    parent_path=$(dirname "$venv_path")
    parent_dir=$(basename "$parent_path")
    venv_name=$(basename "$venv_path")
    
    if [[ "$parent_path" == "$HOME" ]]; then
        env_label="$venv_name"
    else
        env_label="${parent_dir}_${venv_name}"
    fi
    
    echo "  Exporting $env_label..."
    
    if "$venv_path/bin/python" -c 'import sys' 2>/dev/null; then
        "$venv_path/bin/python" --version > "$ENV_DIR/$env_label-version.txt"

        # uv works even without pip in the venv, and keeps git/editable sources
        if command -v uv > /dev/null; then
            uv pip freeze --python "$venv_path/bin/python" > "$ENV_DIR/$env_label-requirements.txt" 2>/dev/null
        else
            "$venv_path/bin/python" -m pip freeze > "$ENV_DIR/$env_label-requirements.txt"
        fi

        # juliacall keeps its Julia project inside the venv
        if [ -f "$venv_path/julia_env/Project.toml" ]; then
            mkdir -p "$ENV_DIR/$env_label-julia_env"
            cp "$venv_path"/julia_env/*.toml "$ENV_DIR/$env_label-julia_env/"
            echo "  ✓ Captured $env_label julia_env"
        fi
    else
        echo "  ! Skipping $env_label (Python missing or broken)"
    fi
done

# Conda Environments
if command -v conda > /dev/null; then
    conda env list | awk 'NF && $1 !~ /^#/ {print $1}' | while read -r env_name; do
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
sudo chown -R "$USER:$(id -gn)" "$SYS_DIR"

# Make sure the scratch/staging tmp/ folder never gets committed to the dotfiles repo
GITIGNORE="$BACKUP_DIR/.gitignore"
touch "$GITIGNORE"
if ! grep -qxF "tmp/" "$GITIGNORE"; then
    echo "tmp/" >> "$GITIGNORE"
    echo "✓ Added tmp/ to .gitignore"
fi

echo "All backups completed successfully!"