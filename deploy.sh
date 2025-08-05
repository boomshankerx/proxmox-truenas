#!/bin/env bash

dpkg-query -W pve-manager
dpkg-query -W libpve-storage-perl

apt reinstall pve-manager
apt reinstall libpve-storage-perl

rsync perl5/TrueNAS /usr/share/perl5/ -av --delete

patch -p0 --verbose -d /usr/share/perl5/PVE/Storage < perl5/PVE/Storage/ZFSPlugin.pm.patch
patch -p0 --verbose -d /usr/share/pve-manager/js < pve-manager/js/pvemanagerlib.js.patch

echo "[+] Restarting Proxmox services..."
service pve-cluster restart && service pvedaemon restart && service pvestatd restart && service pveproxy restart
