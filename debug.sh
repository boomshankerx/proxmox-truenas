#/bin/env bash

cp -v /usr/share/perl5/PVE/Storage/ZFSPlugin.debug.pm /usr/share/perl5/PVE/Storage/ZFSPlugin.pm
cp -v /usr/share/perl5/PVE/Storage/ZFSPoolPlugin.debug.pm /usr/share/perl5/PVE/Storage/ZFSPoolPlugin.pm
cp -v /usr/share/perl5/PVE/Storage/Plugin.debug.pm /usr/share/perl5/PVE/Storage/Plugin.pm

mkdir -p /usr/share/perl5/PVE/Storage/Custom
cp -v perl5/PVE/Storage/Custom/TrueNAS.pm /usr/share/perl5/PVE/Storage/Custom/TrueNAS.pm

echo "[+] Restarting Proxmox services..."
systemctl restart pve-cluster pvedaemon pvestatd pveproxy