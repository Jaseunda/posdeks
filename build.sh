#!/bin/bash

set -e

WORKDIR="/pockosbuild/pockOS"
PROFILE="releng"
LOGFILE="/pockosbuild/build.log"

usage() {
  echo "Usage: $0 {build|clean}"
  exit 1
}

clean() {
  echo "[+] Cleaning working directory $WORKDIR ..."
  sudo rm -rf "$WORKDIR"
  echo "[+] Clean complete."
}

build() {
  echo "[+] Setting up working directory at $WORKDIR ..."
  sudo mkdir -p "$WORKDIR"
  sudo chown $USER:$USER "$WORKDIR"

  echo "[+] Copying ArchISO profile ($PROFILE) ..."
  cp -r /usr/share/archiso/configs/$PROFILE "$WORKDIR"

  # Rename folder to pockOS
  mv "$WORKDIR/$PROFILE" "$WORKDIR/pockOS"

  echo "[+] Syncing host root filesystem to airootfs ..."
  sudo rm -rf "$WORKDIR/pockOS/airootfs"
  mkdir -p "$WORKDIR/pockOS/airootfs"

  sudo rsync -aAXHv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/home/*/.cache/*"} / "$WORKDIR/pockOS/airootfs"

  echo "[+] Copying /home/jas to /home/private in airootfs ..."
  sudo rm -rf "$WORKDIR/pockOS/airootfs/home/private"
  sudo rsync -aAXHv /home/jas/ "$WORKDIR/pockOS/airootfs/home/private"

  # Fix ownership inside airootfs so private user owns home dir
  sudo chown -R 1000:1000 "$WORKDIR/pockOS/airootfs/home/private"

  echo "[+] Starting pockOS ISO build..."
  sudo mkarchiso -v -w "$WORKDIR/pockOS/work" -o "$WORKDIR/pockOS/out" "$WORKDIR/pockOS"

  echo "[+] Build complete. ISO is here:"
  ls -lh "$WORKDIR/pockOS/out"
}

if [ $# -ne 1 ]; then
  usage
fi

case "$1" in
  clean)
    clean
    ;;
  build)
    build
    ;;
  *)
    usage
    ;;
esac
