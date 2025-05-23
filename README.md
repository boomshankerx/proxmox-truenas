# TrueNAS ZFS over iSCSI interface

# THIS PLUGIN IS CURRENTLY ALPHA. THIS REPO IS FOR TESTING AND CODE REVIEW. PLEASE DO NOT RUN THIS IN A PRODUCTION SYSTEM.

## This plugin is based off of https://github.com/TheGrandWazoo/freenas-proxmox. It has been converted to be compatible with the TrueNAS WebSocket API. It is currently being targeted at Proxmox VE 8+ and TrueNAS 24.04+


#### NOTE: Please be aware that this plugin uses the TrueNAS APIs but still uses SSH keys due to the underlying Proxmox VE perl modules that use the `iscsiadm` command.

You will still need to configure the SSH connector for listing the ZFS Pools because this is currently being done in a Proxmox module (ZFSPoolPlugin.pm). To configure this please follow the steps at https://pve.proxmox.com/wiki/Storage:_ZFS_over_iSCSI that have to do with SSH between Proxmox VE and TrueNAS. The code segment should start out `mkdir /etc/pve/priv/zfs`.

1. Remember to follow the instructions mentioned above for the SSH keys.

2. Refresh the Proxmox GUI in your browser to load the new Javascript code.

3. Add your new TrueNAS ZFS-over-iSCSI storage using the TrueNAS-API.

4. Thanks for your support.
