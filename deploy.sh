#!/bin/env bash
dpkg-query -W pve-docs
dpkg-query -W pve-manager
dpkg-query -W libpve-storage-perl

PATCH_ARGS="-p1 -b --ignore-whitespace --verbose"
PATH_APIDocs="/usr/share/pve-docs/api-viewer/apidocs.js"
PATH_Helper="/usr/share/perl5/TrueNAS/Helpers.pm"
PATH_Manager="/usr/share/pve-manager/js/pvemanagerlib.js"
PATH_Native="/usr/share/perl5/PVE/Storage/Custom/TrueNASPlugin.pm"
PATH_ZFSPlugin="/usr/share/perl5/PVE/Storage/ZFSPlugin.pm"

ver=$(dpkg-query -W proxmox-ve | awk '{ print $2}' | cut -d'.' -f1)

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--debug)
      debug=true
      shift
      ;;
    -r|--reinstall)
      reinstall=true
      shift 
      ;;
    -p|--patch)
      patch=true
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# Reinstall Proxmox originals
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

# Patch ZFS over iSCSI plugin files
if [ $patch ]; then
  echo "[+] Patching ZFS over iSCSI..."

  echo "[+] Removing Native TrueNAS Plugin..."
  rm -f ${PATH_Native}

  cp perl5/PVE/Storage/LunCmd/TrueNAS.pm /usr/share/perl5/PVE/Storage/LunCmd

  # Patching ZFSPlugin.pm
  echo "[+] Patching ZFSPlugin.pm..."
  patch ${PATCH_ARGS} /usr/share/perl5/PVE/Storage/ZFSPlugin.pm < perl5/PVE/Storage/ZFSPlugin.pm.${ver}.patch

  # Patching pvemanagerlib.js
  echo "[+] Patching pvemanagerlib.js..."
  patch ${PATCH_ARGS} /usr/share/pve-manager/js/pvemanagerlib.js < pve-manager/js/pvemanagerlib.js.${ver}.patch

else
  echo "[+] Copying TrueNAS Storage Plugin..."
  mkdir -p /usr/share/perl5/PVE/Storage/Custom
  cp perl5/PVE/Storage/Custom/TrueNASPlugin.pm /usr/share/perl5/PVE/Storage/Custom
  [[ -f /usr/share/perl5/PVE/Storage/Custom/TrueNAS.pm ]] && rm -f /usr/share/perl5/PVE/Storage/Custom/TrueNAS.pm
fi

echo "[+] Copying TrueNAS Client..."
rsync perl5/TrueNAS /usr/share/perl5/ -av --delete

if [ $debug ]; then
  sed -i "s/log_level => 'info'/log_level => 'debug'/g" ${PATH_Helper}
fi

echo "[+] Restarting Proxmox services..."
systemctl restart corosync pve-cluster pvedaemon pvestatd pveproxy
