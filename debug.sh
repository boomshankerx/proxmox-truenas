#/bin/env bash

cp -v /usr/share/perl5/PVE/Storage/ZFSPlugin.debug.pm /usr/share/perl5/PVE/Storage/ZFSPlugin.pm
cp -v /usr/share/perl5/PVE/Storage/ZFSPoolPlugin.debug.pm /usr/share/perl5/PVE/Storage/ZFSPoolPlugin.pm
cp -v /usr/share/perl5/PVE/Storage/Plugin.debug.pm /usr/share/perl5/PVE/Storage/Plugin.pm

echo "[+] Restarting Proxmox services..."
systemctl restart pve-cluster pvedaemon pvestatd pveproxy