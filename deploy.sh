#!/bin/env bash

rsync -av --relative perl5/ pve-manager/js/pvemanagerlib.js.apikey.patch /usr/share/

#ZFSPlugin
cd perl5/PVE/Storage
diff -ruN ZFSPlugin.pm.orig ZFSPlugin.pm > ZFSPlugin.pm.patch
cd -
cp -v /usr/share/perl5/PVE/Storage/ZFSPlugin.pm.orig /usr/share/perl5/PVE/Storage/ZFSPlugin.pm
patch -p0 --verbose -d /usr/share/perl5/PVE/Storage < perl5/PVE/Storage/ZFSPlugin.pm.patch


# pve-manager
cd pve-manager/js/
diff -ruN pvemanagerlib.js.orig pvemanagerlib.js >pvemanagerlib.js.patch
cd -
cp -v /usr/share/pve-manager/js/pvemanagerlib.js.orig /usr/share/pve-manager/js/pvemanagerlib.js
patch -p0 --verbose -d /usr/share/pve-manager/js/ <pve-manager/js/pvemanagerlib.js.apikey.patch


# pve-docs/api-viewer
cd pve-docs/api-viewer
diff -ruN apidoc.js.orig apidoc.js >apidoc.js.patch
cd -
cp -v /usr/share/pve-docs/api-viewer/apidoc.js.orig /usr/share/pve-docs/api-viewer/apidoc.js
patch -p0 --verbose -d /usr/share/pve-docs/api-viewer <pve-docs/api-viewer/apidoc.js.patch

service pve-cluster restart && service pvedaemon restart && service pvestatd restart && service pveproxy restart
