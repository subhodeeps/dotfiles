# System Configuration Reference

This directory contains configuration files for the Arch Linux environment.

**WARNING: Manual restoration required. Do not use automated scripts to blindly overwrite files in `/etc/`. System-specific identifiers (e.g., UUIDs in `fstab`) must be verified and updated to match the target machine to prevent boot failure.**

## 1. Boot & Hardware

* **fstab**: Contains mount points and options. Copy only relevant mount options (e.g., `x-systemd.automount`). **Do not overwrite existing UUIDs.**
* **grub**: `/etc/default/grub`. Post-restore command: `sudo grub-mkconfig -o /boot/grub/grub.cfg`
* **mkinitcpio.conf**: `/etc/mkinitcpio.conf`. Post-restore command: `sudo mkinitcpio -P`
* **throttled.conf**: CPU/Undervolt parameters. Service: `sudo systemctl enable --now throttled`
* **thinkfan.conf**: Thermal control configuration. Service: `sudo systemctl enable --now thinkfan`

## 2. Graphics

* **optimus-manager.conf**: GPU management configuration (set to `hybrid` mode).

## 3. Zram Configuration

* **zram-generator.conf**: Zram block device parameters.
* **99-vm-zram-parameters.conf**: Kernel `sysctl` memory parameters.
* **Activation**:
```bash
sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0.service
sudo sysctl --system

```



## 4. Package Management

* **pacman.conf**: Configuration for package operations (parallel downloads, color, etc.).
* **pkglist-official.txt**: Explicitly installed packages from official repositories.
* Restore: `sudo pacman -S --needed - < pkglist-official.txt`


* **pkglist-aur.txt**: Explicitly installed AUR packages.
* Restore: `yay -S --needed - < pkglist-aur.txt`



## 5. Runtime Environments

* **julia-global**: Contains `Project.toml` and `Manifest.toml` from `~/.julia/environments/v1.x/`.
* Restore: Place in `~/.julia/environments/v1.x/` and run `using Pkg; Pkg.instantiate()` in the Julia REPL.


* **python-envs**: Contains environment version markers and `pip` freeze lists.
* Restore: Create virtual environment and execute: `pip install -r <name>-requirements.txt`.