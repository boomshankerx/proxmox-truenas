#!/bin/env bash
dpkg-query -W pve-manager
dpkg-query -W libpve-storage-perl

ZFSPluginPath="/usr/share/perl5/PVE/Storage/ZFSPlugin.pm"
PVEManagerPath="/usr/share/pve-manager/js/pvemanagerlib.js"

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
    rm ${ZFSPluginPath}.orig
    rm ${PVEManagerPath}.orig
    apt reinstall pve-manager
    apt reinstall libpve-storage-perl
else
    echo "Restoring original files..."
    mv ${ZFSPluginPath}.orig ${ZFSPluginPath}
    mv ${PVEManagerPath}.orig ${PVEManagerPath}
fi

# Patching ZFSPlugin.pm
echo "[+] Patching ZFSPlugin.pm..."
patch -b -p0 --verbose -d /usr/share/perl5/PVE/Storage < perl5/PVE/Storage/ZFSPlugin.pm.patch

# Patching pvemanagerlib.js
echo "[+] Patching pvemanagerlib.js..."
patch -b -p0 --verbose -d /usr/share/pve-manager/js < pve-manager/js/pvemanagerlib.js.patch

echo "[+] Copying TrueNAS Client..."
rsync perl5/TrueNAS /usr/share/perl5/ -av --delete

echo "[+] Restarting Proxmox services..."
systemctl restart pve-cluster && systemctl restart pvedaemon && systemctl restart pvestatd && systemctl restart pveproxy
