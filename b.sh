#!/bin/bash

set -e

############################################
# Configuration
############################################
WORKDIR="/pockosbuild/pockOS"
PROFILE_NAME="releng"
ISO_LABEL="pockOS"
LOGFILE="/pockosbuild/build.log"
HOST_USER="jas"
LIVE_USER="private"
LIVE_UID=1000
LIVE_GID=1000

############################################
# Functions
############################################
info()    { echo -e "[i] $1"; }
success() { echo -e "[✓] $1"; }
error()   { echo -e "[✗] $1"; }

usage() {
    echo "Usage: $0 {build|clean}"
    exit 1
}

clean() {
    info "Removing working directory: $WORKDIR"
    sudo rm -rf "/pockosbuild"
    success "Clean complete."
}

build() {
    info "Creating work directory at $WORKDIR..."
    sudo mkdir -p "$WORKDIR"
    sudo chown -R "$USER:$USER" "/pockosbuild"

    info "Copying ArchISO profile ($PROFILE_NAME)..."
    cp -r "/usr/share/archiso/configs/$PROFILE_NAME" "$WORKDIR"
    mv "$WORKDIR/$PROFILE_NAME" "$WORKDIR/pockOS"

    ########################################
    # Sync host root filesystem into airootfs
    ########################################
    info "Preparing airootfs..."
    sudo rm -rf "$WORKDIR/pockOS/airootfs"
    mkdir -p "$WORKDIR/pockOS/airootfs"

    info "Copying host root (excluding special dirs)..."
    sudo rsync -aAXHv \
        --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/home/*/.cache/*"} \
        / "$WORKDIR/pockOS/airootfs"

    ########################################
    # Copy host home to /home/private in airootfs
    ########################################
    info "Copying /home/$HOST_USER → /home/$LIVE_USER in airootfs..."
    sudo rm -rf "$WORKDIR/pockOS/airootfs/home/$LIVE_USER"
    sudo rsync -aAXHv "/home/$HOST_USER/" "$WORKDIR/pockOS/airootfs/home/$LIVE_USER"
    sudo chown -R "$LIVE_UID:$LIVE_GID" "$WORKDIR/pockOS/airootfs/home/$LIVE_USER"

    ########################################
    # Create customize_airootfs.sh
    ########################################
    info "Creating customize_airootfs.sh for live-user setup..."
    cat << 'EOF' > "$WORKDIR/pockOS/airootfs/root/customize_airootfs.sh"
#!/bin/bash
set -e

LIVE_USER="private"
LIVE_UID=1000
LIVE_GID=1000

# Create live user if not exists
if ! id -u "$LIVE_USER" &>/dev/null; then
    useradd -m -u "$LIVE_UID" -U -G wheel -s /bin/bash "$LIVE_USER"
    echo "$LIVE_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/"$LIVE_USER"
fi

# Ensure home dir ownership (copy process already did, but just in case)
chown -R "$LIVE_UID:$LIVE_GID" /home/"$LIVE_USER"

# Enable autologin on tty1 for live user
mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat << EOL > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $LIVE_USER --noclear %I \$TERM
EOL

EOF
    chmod +x "$WORKDIR/pockOS/airootfs/root/customize_airootfs.sh"

    ########################################
    # Rebrand ISO name in profiledef.sh
    ########################################
    info "Rebranding ISO in profiledef.sh → $ISO_LABEL..."
    sed -i "s|^ARCHISO_NAME=.*|ARCHISO_NAME=\"$ISO_LABEL\"|" "$WORKDIR/pockOS/profiledef.sh"
    sed -i "s|^iso_name=.*|iso_name=\"$ISO_LABEL\"|" "$WORKDIR/pockOS/profiledef.sh"

    ########################################
    # Build the ISO
    ########################################
    info "Building pockOS ISO... (this may take a while)"
    sudo mkarchiso -v \
        -w "$WORKDIR/pockOS/work" \
        -o "$WORKDIR/pockOS/out" \
        "$WORKDIR/pockOS" 2>&1 | tee "$LOGFILE"

    # Locate the generated ISO
    ISO_PATH=$(find "$WORKDIR/pockOS/out" -maxdepth 1 -type f -name "*.iso" | head -n 1)
    if [[ -f "$ISO_PATH" ]]; then
        success "ISO built: $ISO_PATH"
    else
        error "ISO build failed. See log: $LOGFILE"
        exit 1
    fi
}

############################################
# Main
############################################
if [[ $# -ne 1 ]]; then
    usage
fi

case "$1" in
    build) build ;;
    clean) clean ;;
    *) usage ;;
esac
