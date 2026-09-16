#!/bin/bash

OUTPUT_FILE="aur_pkgbuilds_to_inspect.txt"

# Clear the output file if it already exists
> "$OUTPUT_FILE"

echo "Checking for pending AUR updates..."
# Fetch the list of AUR packages that need an update
PACKAGES=$(yay -Qua | awk '{print $1}')

# If no updates are found, fallback to all installed AUR packages
if [ -z "$PACKAGES" ]; then
    echo "No pending AUR updates found. Fetching PKGBUILDs for ALL installed AUR packages..."
    PACKAGES=$(pacman -Qm | awk '{print $1}')
else
    echo "Found pending updates. Fetching PKGBUILDs..."
fi

# Loop through the packages and download their PKGBUILDs
for pkg in $PACKAGES; do
    echo " -> Fetching $pkg"
    
    echo -e "\n==================================================" >> "$OUTPUT_FILE"
    echo "PACKAGE: $pkg" >> "$OUTPUT_FILE"
    echo "==================================================" >> "$OUTPUT_FILE"
    
    # Use curl to fetch the raw PKGBUILD file directly from the AUR web interface
    HTTP_STATUS=$(curl -sL -w "%{http_code}" -o temp_pkgbuild "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$pkg")
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        cat temp_pkgbuild >> "$OUTPUT_FILE"
    else
        echo "[!] Error fetching PKGBUILD. The package might be a split package or removed." >> "$OUTPUT_FILE"
    fi
    
    rm -f temp_pkgbuild
done

echo ""
echo "Done! All PKGBUILDs have been saved to: $OUTPUT_FILE"
