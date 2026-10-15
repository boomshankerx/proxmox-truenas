#!/usr/bin/env bash
set -Eeuo pipefail

# Load shared helpers from the script directory.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/script-common.sh"

# Parse options before checking packages or changing files.
debug=false
reinstall=false
patch_mode=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--debug) debug=true ;;
    -r|--reinstall) reinstall=true ;;
    -p|--patch) patch_mode=true ;;
    -h|--help)
      echo "Usage: $0 [--patch] [--reinstall] [--debug]"
      echo "Default: install Native. --patch installs the alternative ZFS-over-iSCSI plugin."
      exit 0 ;;
    *) fail "Unknown argument: $1 (use --help)" ;;
  esac
  shift
done

# Define installed file locations.
PATH_Helper="/usr/share/perl5/TrueNAS/Helpers.pm"
PATH_Manager="/usr/share/pve-manager/js/pvemanagerlib.js"
PATH_Native="/usr/share/perl5/PVE/Storage/Custom/TrueNASPlugin.pm"
PATH_ZFSPlugin="/usr/share/perl5/PVE/Storage/ZFSPlugin.pm"
PATH_LunCmd="/usr/share/perl5/PVE/Storage/LunCmd"

# Check required tools and the installed PVE version.
commands=(dpkg-query cp mv rm mkdir mktemp rsync systemctl)
$patch_mode && commands+=(patch)
$reinstall && commands+=(apt)
$debug && commands+=(sed)
require_commands "${commands[@]}"
manager_version=$(query_package_version pve-manager)
storage_version=$(query_package_version libpve-storage-perl)
ver=$(detect_pve_version "$manager_version")

# Check the source files required by the selected mode.
resources=("$SCRIPT_DIR/perl5/TrueNAS/Client.pm" "$SCRIPT_DIR/perl5/TrueNAS/Helpers.pm")
if $patch_mode; then
  resources+=("$SCRIPT_DIR/perl5/PVE/Storage/LunCmd/TrueNAS.pm"
              "$SCRIPT_DIR/perl5/PVE/Storage/ZFSPlugin.pm.$ver.patch"
              "$SCRIPT_DIR/pve-manager/js/pvemanagerlib.js.$ver.patch")
else
  resources+=("$SCRIPT_DIR/perl5/PVE/Storage/Custom/TrueNASPlugin.pm")
fi
for resource in "${resources[@]}"; do
  [[ -f "$resource" && -r "$resource" ]] || fail "Missing readable resource: $resource"
done

# Report the failed stage and clean up temporary patch files.
stage="preparing deployment"
work=""
trap 'echo "[!] Failed while $stage. Deployment stopped; no successful completion. Check the reported step and retained .orig backups before retrying." >&2' ERR
trap 'if [[ -n "$work" ]]; then rm -rf -- "$work"; fi' EXIT

# Optionally reinstall Proxmox packages before preparing plugin files.
if $reinstall; then
  stage="reinstalling Proxmox packages"
  # Keep existing backups until reinstall and patch preparation have succeeded.
  apt reinstall pve-manager libpve-storage-perl
fi

# Prepare both patches on copies before installing either result.
targets=("$PATH_ZFSPlugin" "$PATH_Manager")
if $patch_mode; then
  stage="preparing patches"
  work=$(mktemp -d)
  patch_files=("$SCRIPT_DIR/perl5/PVE/Storage/ZFSPlugin.pm.$ver.patch"
               "$SCRIPT_DIR/pve-manager/js/pvemanagerlib.js.$ver.patch")
  for index in "${!targets[@]}"; do
    target=${targets[$index]}
    original=$target
    if ! $reinstall && [[ -f "$target.orig" ]]; then original="$target.orig"; fi
    [[ -f "$original" && -r "$original" ]] || fail "Missing original: $original"
    cp -- "$original" "$work/$index.orig"
    cp -- "$original" "$work/$index"
    # Check both patches on copies before replacing any installed plugin file.
    patch --batch --forward --ignore-whitespace "$work/$index" < "${patch_files[$index]}"
  done
fi

# Install the shared client and optionally enable debug logging.
stage="copying TrueNAS client"
rsync -av --delete "$SCRIPT_DIR/perl5/TrueNAS" /usr/share/perl5/
if $debug; then
  stage="enabling debug logging"
  sed -i "s/log_level => 'info'/log_level => 'debug'/g" "$PATH_Helper"
fi

# Install Patch mode, or restore originals and install Native mode.
if $patch_mode; then
  stage="installing ZFS-over-iSCSI patches"
  mkdir -p -- "$PATH_LunCmd"
  cp -- "$SCRIPT_DIR/perl5/PVE/Storage/LunCmd/TrueNAS.pm" "$PATH_LunCmd/TrueNAS.pm"
  for index in "${!targets[@]}"; do
    target=${targets[$index]}
    cp -- "$work/$index.orig" "$target.orig"
    cp -- "$work/$index" "$target"
  done
  rm -f -- "$PATH_Native"
else
  stage="restoring Proxmox originals"
  for target in "${targets[@]}"; do
    if $reinstall; then
      rm -f -- "$target.orig"
    elif [[ -f "$target.orig" ]]; then
      mv -- "$target.orig" "$target"
    fi
  done
  stage="installing Native plugin"
  mkdir -p -- "${PATH_Native%/*}"
  cp -- "$SCRIPT_DIR/perl5/PVE/Storage/Custom/TrueNASPlugin.pm" "$PATH_Native"
  rm -f -- /usr/share/perl5/PVE/Storage/Custom/TrueNAS.pm
fi

# Restart services only after all installation steps have succeeded.
stage="restarting Proxmox services"
# TODO: Consider restarting only pvedaemon, pvestatd and pveproxy after
# validating on real PVE that corosync and pve-cluster do not need a restart.
# Preserve the original restart list until then.
systemctl restart corosync pve-cluster pvedaemon pvestatd pveproxy
echo "[+] Deployment completed."
