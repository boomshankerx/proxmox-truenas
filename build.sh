#!/bin/env bash
dpkg-query -W pve-manager
dpkg-query -W libpve-storage-perl

ver=$(dpkg-query -W pve-manager | awk '{print $2}' | cut -d. -f1)

#ZFSPlugin
cd perl5/PVE/Storage
diff -ruN ZFSPlugin.pm.$ver.orig ZFSPlugin.pm.$ver > ZFSPlugin.pm.$ver.patch
cd -

# pve-manager
cd pve-manager/js/
diff -ruN pvemanagerlib.js.$ver.orig pvemanagerlib.js.$ver >pvemanagerlib.js.$ver.patch
cd -

# pve-docs/api-viewer
# cd pve-docs/api-viewer
# diff -ruN apidoc.js.orig apidoc.js >apidoc.js.patch.$ver
# cd -