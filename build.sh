#!/usr/bin/env bash
set -euo pipefail

fail() { echo "[!] $*" >&2; exit 1; }
[[ $# -eq 0 ]] || fail "Usage: $0"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
for command in dpkg-query diff mktemp mv rm; do
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

sources=("$SCRIPT_DIR/perl5/PVE/Storage/ZFSPlugin.pm.$ver"
         "$SCRIPT_DIR/pve-manager/js/pvemanagerlib.js.$ver")
for source in "${sources[@]}"; do
  [[ -f "$source.orig" && -r "$source.orig" ]] || fail "Missing readable input: $source.orig"
  [[ -f "$source" && -r "$source" ]] || fail "Missing readable input: $source"
done

temporary=()
cleanup() {
  for file in "${temporary[@]}"; do rm -f -- "$file"; done
}
trap cleanup EXIT
for source in "${sources[@]}"; do
  output=$(mktemp "$source.patch.XXXXXX")
  temporary+=("$output")
  directory=${source%/*}
  filename=${source##*/}
  # diff returns 1 for a valid difference, and >1 for an execution error.
  if (cd -- "$directory" && diff -u -- "$filename.orig" "$filename") > "$output"; then
    :
  else
    status=$?
    [[ $status -eq 1 ]] || fail "diff failed for $source (status $status); existing patches were preserved"
  fi
done

# Publish only after every input has been checked and both diffs succeeded.
for index in "${!sources[@]}"; do
  mv -- "${temporary[$index]}" "${sources[$index]}.patch"
done
echo "[+] Generated PVE $ver patches (pve-manager $manager_version, libpve-storage-perl $storage_version)."
