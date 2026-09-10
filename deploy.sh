#!/usr/bin/env bash
set -Eeuo pipefail

fail() { echo "[!] $*" >&2; exit 1; }
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

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PATH_Helper="/usr/share/perl5/TrueNAS/Helpers.pm"
PATH_Manager="/usr/share/pve-manager/js/pvemanagerlib.js"
PATH_Native="/usr/share/perl5/PVE/Storage/Custom/TrueNASPlugin.pm"
PATH_ZFSPlugin="/usr/share/perl5/PVE/Storage/ZFSPlugin.pm"
PATH_LunCmd="/usr/share/perl5/PVE/Storage/LunCmd"

commands=(dpkg-query cp mv rm mkdir mktemp rsync systemctl)
$patch_mode && commands+=(patch)
$reinstall && commands+=(apt)
$debug && commands+=(sed)
for command in "${commands[@]}"; do
  command -v "$command" >/dev/null || fail "Missing command: $command"
done
manager_version=$(dpkg-query -W -f='${Version}' pve-manager) || fail "Cannot query pve-manager version"
storage_version=$(dpkg-query -W -f='${Version}' libpve-storage-perl) || fail "Cannot query libpve-storage-perl version"
case "$manager_version" in
  8.*) ver=8 ;;
  9.*) ver=9 ;;
  *) fail "Unsupported pve-manager version: $manager_version" ;;
esac
[[ -n "$storage_version" ]] || fail "Missing libpve-storage-perl version"

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

stage="preparing deployment"
work=""
trap 'echo "[!] Failed while $stage. Deployment stopped; no successful completion. Check the reported step and retained .orig backups before retrying." >&2' ERR
trap 'if [[ -n "$work" ]]; then rm -rf -- "$work"; fi' EXIT

if $reinstall; then
  stage="reinstalling Proxmox packages"
  # Keep existing backups until reinstall and patch preparation have succeeded.
  apt reinstall pve-manager libpve-storage-perl
fi

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

stage="copying TrueNAS client"
rsync -av --delete "$SCRIPT_DIR/perl5/TrueNAS" /usr/share/perl5/
if $debug; then
  stage="enabling debug logging"
  sed -i "s/log_level => 'info'/log_level => 'debug'/g" "$PATH_Helper"
fi

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

stage="restarting Proxmox API and status services"
systemctl restart pvedaemon pvestatd pveproxy
echo "[+] Deployment completed."
