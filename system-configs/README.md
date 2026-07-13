# System Configuration Reference

This directory contains configuration files for the Arch Linux environment on this ThinkPad.

> [!CAUTION]
> **MANUAL RESTORATION REQUIRED.** Do not use automated scripts to blindly overwrite system files. System-specific identifiers (e.g., UUIDs in `fstab`) must be verified against current hardware IDs to prevent boot failure. Misconfiguration of bootloaders or kernel parameters may render the system unbootable.

## 1. Boot & Hardware

* **fstab**: Contains partition mount points and options. Copy only relevant mount options (e.g., `x-systemd.automount`). **NEVER overwrite existing UUIDs** with old ones from this backup.
* **grub**: `/etc/default/grub`. Post-restore: `sudo grub-mkconfig -o /boot/grub/grub.cfg`
* **mkinitcpio.conf**: `/etc/mkinitcpio.conf`. Post-restore: `sudo mkinitcpio -P`
* **throttled.conf**: CPU/Undervolt parameters. Apply via: `sudo systemctl enable --now throttled`
* **thinkfan.conf**: Thermal control configuration. Apply via: `sudo systemctl enable --now thinkfan`

## 2. Graphics

* **optimus-manager.conf**: GPU management configuration. Ensure appropriate modes are set based on current driver state.

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

* **pacman.conf**: Configuration for package operations.
* **pkglist-official.txt**: Explicitly installed packages from official repositories.
  * *Restore*: `sudo pacman -S --needed - < pkglist-official.txt`
* **pkglist-aur.txt**: Explicitly installed AUR packages.
  * *Restore*: `yay -S --needed - < pkglist-aur.txt`

## 5. Runtime Environments

* **julia-global**: Contains `Project.toml` and `Manifest.toml` from `~/.julia/environments/v1.x/`.
  * *Restore*: Place files in `~/.julia/environments/v1.x/` and run `using Pkg; Pkg.instantiate()` in the Julia REPL.
* **python-envs**: Contains environment version markers and `pip` freeze lists.
  * *Restore*:
    1. Create a virtual environment: `python -m venv myenv`
    2. Activate: `source myenv/bin/activate`
    3. Install requirements: `pip install -r <name>-requirements.txt`
    4. For global user packages: `pip install --user -r global-requirements.txt`

## 6. Systemd-Boot (Primary)

Configurations located in the EFI System Partition under `/loader/`.

* *Post-restore*: Run `sudo bootctl update` to ensure the bootloader is correctly synchronized.
