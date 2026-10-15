#!/usr/bin/env bash
# Shared helpers for build.sh and deploy.sh; sourcing this file only defines functions.

# Print an error and stop the calling script.
fail() { echo "[!] $*" >&2; exit 1; }

# Check every command required by the selected operation.
require_commands() {
  local command
  for command in "$@"; do
    command -v "$command" >/dev/null || fail "Missing command: $command"
  done
}

# Print a package version; errors go to stderr and stop the caller's command.
query_package_version() {
  local package=$1 version
  version=$(dpkg-query -W -f='${Version}' "$package") || fail "Cannot query $package version"
  [[ -n "$version" ]] || fail "Missing $package version"
  printf '%s\n' "$version"
}

# Print the supported PVE major version for the supplied pve-manager version.
detect_pve_version() {
  local manager_version=$1
  case "$manager_version" in
    8.*) printf '%s\n' 8 ;;
    9.*) printf '%s\n' 9 ;;
    *) fail "Unsupported pve-manager version: $manager_version" ;;
  esac
}
