#!/bin/env bash

ver=$(dpkg-query -W pve-manager | awk '{print $2}' | cut -d. -f1)

apt reinstall pve-manager libpve-storage-perl -y

cp -vr /usr/share/perl5/PVE/Storage/ZFSPlugin.pm perl5/PVE/Storage/ZFSPlugin.pm.$ver.orig
cp -vr /usr/share/pve-manager/js/pvemanagerlib.js pve-manager/js/pvemanagerlib.js.$ver.orig