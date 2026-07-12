# Dotfiles

A collection of configuration files for the terminal environment and desktop workflow.

![Terminal Environment](screenshot/screenshot.png)

## Components

* **Terminal:** Kitty
* **Shell:** Zsh
* **Prompt:** Starship
* **System Info:** Fastfetch
* **Window Management:** Krohnkite (KDE Tiling Script, bindings saved in `kglobalshortcutsrc`)

## Management

Configurations are maintained via a local backup script (`backup.sh`). This script copies the active configurations from their respective system directories into this repository for version control.

### Backup Workflow

```bash
# Pull latest local configs into the repository
./backup.sh

# Commit and push
git add .
git commit -m "Update configurations"
git push