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

echo "Backup complete! Ready to commit and push."
