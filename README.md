# TrueNAS ZFS over iSCSI interface for Proxmox VE

## Acknowledgement
This plugin is based on https://github.com/TheGrandWazoo/freenas-proxmox. It has been converted to be compatible with the TrueNAS WebSocket API. It is currently being targeted at Proxmox VE 8+ and TrueNAS 24.04+

## Compatibility
Proxmox VE 8.4.1  
pve-manager 8.4.5  
libpve-storage-perl 8.3.6  

## Migrating from freenas-proxmox
1. **Uninstall the old freenas-proxmox plugin if you have it installed. `storage.cfg` settings are not compatible between plugins. You can either remove and recreate your connection or edit storage.cfg replacing 'freenas' with 'truenas'
3. Update your proxmox system to the latest version (8.4.1 at the time of this writing)
4. Ensure you have the latest versions of the relevant files `apt reinstall pve-manager libpve-storage-perl`. Uninstalling the plugin restores the files that existed at the time of the last install which may not be current. 
5. Proceed with install

## Install
1. Download the latest release of the .deb file to your Proxmox host
2. Install the .deb package using `sudo apt install <deb>`
3. Create ZFS over iSCSI connection

## Example config
```
zfs: nas
    blocksize 16k
    iscsiprovider truenas
    pool VMFS1/proxmox
    portal 10.0.0.1
    target iqn.2005-10.org.freenas.ctl:proxmox
    content images
    nowritecache 0
    sparse 1
    truenas_apikey <APIKEY>
    truenas_apiv4_host 10.0.0.1
    truenas_use_ssl 1
    truenas_user admin
```

This plugin requires that TrueNAS iSCSI is properly configured prior to connecting
https://www.truenas.com/docs/scale/25.04/scaleuireference/shares/iscsisharesscreens/

### NOTE: Please be aware that this plugin uses the TrueNAS APIs but still uses SSH keys.
You will still need to configure the SSH connector for listing the ZFS Pools because this is currently being done in a Proxmox module (ZFSPoolPlugin.pm). To configure this please follow the steps at https://pve.proxmox.com/wiki/Storage:_ZFS_over_iSCSI that have to do with SSH between Proxmox VE and TrueNAS. The code segment should start out `mkdir /etc/pve/priv/zfs`.
1. Remember to follow the instructions mentioned above for the SSH keys.
2. Refresh the Proxmox GUI in your browser to load the new Javascript code.
3. Add your new TrueNAS ZFS-over-iSCSI storage using the TrueNAS-API.
4. Thanks for your support.
