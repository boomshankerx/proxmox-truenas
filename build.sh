#!/usr/bin/env bash
set -euo pipefail

# Load shared helpers from the script directory.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/script-common.sh"

# Validate arguments, tools and the installed PVE version.
[[ $# -eq 0 ]] || fail "Usage: $0"
require_commands dpkg-query diff mktemp mv rm
manager_version=$(query_package_version pve-manager)
storage_version=$(query_package_version libpve-storage-perl)
ver=$(detect_pve_version "$manager_version")

# Check both original and edited inputs before generating patches.
sources=("$SCRIPT_DIR/perl5/PVE/Storage/ZFSPlugin.pm.$ver"
         "$SCRIPT_DIR/pve-manager/js/pvemanagerlib.js.$ver")
for source in "${sources[@]}"; do
  [[ -f "$source.orig" && -r "$source.orig" ]] || fail "Missing readable input: $source.orig"
  [[ -f "$source" && -r "$source" ]] || fail "Missing readable input: $source"
done

# Generate into temporary files and remove them on exit.
temporary=()
cleanup() {
  local file
  for file in "$@"; do rm -f -- "$file"; done
}
trap 'cleanup "${temporary[@]}"' EXIT
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
