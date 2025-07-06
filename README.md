# TrueNAS ZFS over iSCSI interface

## Acknowledgement
This plugin is based on https://github.com/TheGrandWazoo/freenas-proxmox. It has been converted to be compatible with the TrueNAS WebSocket API. It is currently being targeted at Proxmox VE 8+ and TrueNAS 24.04+

## Install
1. **Please uninstall the old freenas-proxmox plugin of you have it installed. This plugin is not compatible with the existing config. You will need to recreate your storage once the new plugin is installed.**
2. Download the latest release of the .deb file to your Proxmox host
3. Install the .deb package using `sudo apt install <deb>`

This plugin requires that TrueNAS iSCSI is properly configured prior to connecting
https://www.truenas.com/docs/scale/25.04/scaleuireference/shares/iscsisharesscreens/

### NOTE: Please be aware that this plugin uses the TrueNAS APIs but still uses SSH keys.
You will still need to configure the SSH connector for listing the ZFS Pools because this is currently being done in a Proxmox module (ZFSPoolPlugin.pm). To configure this please follow the steps at https://pve.proxmox.com/wiki/Storage:_ZFS_over_iSCSI that have to do with SSH between Proxmox VE and TrueNAS. The code segment should start out `mkdir /etc/pve/priv/zfs`.
1. Remember to follow the instructions mentioned above for the SSH keys.
2. Refresh the Proxmox GUI in your browser to load the new Javascript code.
3. Add your new TrueNAS ZFS-over-iSCSI storage using the TrueNAS-API.
4. Thanks for your support.
