#!/bin/env bash

ver=$(dpkg-query -W pve-manager | awk '{print $2}' | cut -d. -f1)

cp -r /usr/share/perl5/PVE/Storage/ZFSPlugin.pm perl5/PVE/Storage/ZFSPlugin.pm.$ver.orig
cp -r /usr/share/pve-manager/js/pvemanagerlib.js pve-manager/js/pvemanagerlib.js.$ver.orig