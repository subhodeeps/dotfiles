# System Configurations Backup

**WARNING:** Do not symlink these files directly back to `/etc/` or `/boot/`.
These files are system-level configurations and require root ownership.

## Restoration Instructions:
1. Use `sudo cp` to restore these files to their respective locations.
2. Ensure proper permissions are set (usually `root:root`).
3. Run necessary post-install hooks after restoring:
   - `sudo mkinitcpio -P` (if mkinitcpio.conf changed)
   - `sudo bootctl update` (for systemd-boot)
   - `sudo grub-mkconfig -o /boot/grub/grub.cfg` (if using GRUB fallback)
