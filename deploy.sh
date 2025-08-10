#!/bin/env bash
dpkg-query -W pve-docs
dpkg-query -W pve-manager
dpkg-query -W libpve-storage-perl

PATH_APIDocs="/usr/share/pve-docs/api-viewer/apidocs.js"
PATH_ZFSPlugin="/usr/share/perl5/PVE/Storage/ZFSPlugin.pm"
PATH_Manager="/usr/share/pve-manager/js/pvemanagerlib.js"
PATCH_ARGS="-p0 -b --ignore-whitespace --verbose"

ver=$(dpkg-query -W proxmox-ve | awk '{ print $2}' | cut -d'.' -f1)


POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--reinstall)
      reinstall=true
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [ $reinstall ]; then
    echo "Reinstalling Proxmox packages..."
    rm ${PATH_ZFSPlugin}.orig
    rm ${PATH_Manager}.orig
    apt reinstall pve-docs
    apt reinstall pve-manager
    apt reinstall libpve-storage-perl
else
    echo "Restoring original files..."
    mv ${PATH_APIDocs}.orig ${PATH_APIDocs}
    mv ${PATH_ZFSPlugin}.orig ${PATH_ZFSPlugin}
    mv ${PATH_Manager}.orig ${PATH_Manager}
fi

# Patching ZFSPlugin.pm
echo "[+] Patching ZFSPlugin.pm..."
patch ${PATCH_ARGS} -d /usr/share/perl5/PVE/Storage < perl5/PVE/Storage/ZFSPlugin.pm.${ver}.patch

# Patching pvemanagerlib.js
echo "[+] Patching pvemanagerlib.js..."
patch ${PATCH_ARGS} -d /usr/share/pve-manager/js < pve-manager/js/pvemanagerlib.js.${ver}.patch

# echo "[+] Patching API docs..."
# patch ${PATCH_ARGS} -d /usr/share/pve-docs/api-viewer < pve-docs/api-viewer/apidoc.js.${ver}.patch

echo "[+] Copying TrueNAS Client..."
rsync perl5/TrueNAS /usr/share/perl5/ -av --delete

echo "[+] Restarting Proxmox services..."
systemctl restart pve-cluster && systemctl restart pvedaemon && systemctl restart pvestatd && systemctl restart pveproxy
