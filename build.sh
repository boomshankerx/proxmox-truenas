#!/bin/env bash
dpkg-query -W pve-manager
dpkg-query -W libpve-storage-perl

#ZFSPlugin
cd perl5/PVE/Storage
diff -ruN ZFSPlugin.pm.837 ZFSPlugin.pm > ZFSPlugin.pm.patch
cd -


# pve-manager
cd pve-manager/js/
diff -ruN pvemanagerlib.js.848 pvemanagerlib.js >pvemanagerlib.js.patch
cd -

# pve-docs/api-viewer
cd pve-docs/api-viewer
diff -ruN apidoc.js.orig apidoc.js >apidoc.js.patch
cd -