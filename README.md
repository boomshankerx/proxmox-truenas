# TrueNAS over iSCSI Custom Storage Plugin for Proxmox

## Acknowledgement

This plugin was made possible by the great work at <https://github.com/TheGrandWazoo/freenas-proxmox>. It has been converted to be compatible with the TrueNAS WebSocket API. It is currently being targeted at Proxmox VE 8+ and TrueNAS 24.04+

## Donations

[![Donate](https://img.shields.io/badge/PayPal-Donate-00457C?logo=paypal&logoColor=white)](https://www.paypal.com/donate?hosted_button_id=QZD95HR69R8KA)

Thank you for supporting open-source. Made with love for the community.

## Compatibility

Proxmox VE 8.4.11 / 9.0.5  
pve-manager 8.4.11 / 9.0.5  
libpve-storage-perl 8.3.7 / 9.0.13  

## Migrating from freenas-proxmox

1. **Uninstall the old freenas-proxmox plugin if you have it installed. `storage.cfg` settings are not compatible between plugins. You can either remove and recreate your connection or edit storage.cfg replacing 'freenas' with 'truenas'
3. Update your proxmox system to the latest version
4. Ensure you have the latest versions of the relevant files `apt reinstall pve-manager libpve-storage-perl`. Uninstalling the plugin restores the files that existed at the time of the last install, which may not be current.
5. Proceed to install

## Install

### APT Repository (Recommended)

1. Import the signing key

```
curl -fsSL https://boomshankerx.github.io/proxmox-truenas-apt/gpg.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/proxmox-truenas.gpg
```

2. Add the repository

Proxmox 8 / Debian 12 (bookworm):

```
echo "deb [signed-by=/usr/share/keyrings/proxmox-truenas.gpg] \
https://boomshankerx.github.io/proxmox-truenas-apt bookworm main" \
| sudo tee /etc/apt/sources.list.d/proxmox-truenas.list
```

Proxmox 9 / Debian 13 (trixie):

```
echo "deb [signed-by=/usr/share/keyrings/proxmox-truenas.gpg] \
https://boomshankerx.github.io/proxmox-truenas-apt trixie main" \
| sudo tee /etc/apt/sources.list.d/proxmox-truenas.list
```

3. Update & install

```
sudo apt update
sudo apt install proxmox-truenas
```

## Manual Installation

1. Download the latest release of the .deb file to your Proxmox host
2. Install the .deb package using `sudo apt install <deb>`
3. Create ZFS over iSCSI connection

### Dependencies

If you want to install dependencies manually

```
apt install libio-socket-ip-perl libio-socket-ssl-perl libjson-rpc-common-perl liblog-any-perl libprotocol-websocket-perl
```

## Example config

```
zfs: nas
    blocksize 16k
    iscsiprovider truenas
    pool tank/proxmox
    portal 10.0.0.1
    target iqn.2005-10.org.freenas.ctl:proxmox
    content images
    nowritecache 0
    sparse 1
    truenas_apikey <APIKEY>
    truenas_apiv4_host 10.0.0.1
    truenas_use_ssl 1
    truenas_user <USER>
    truenas_password <PASSWORD>
```

This plugin requires that TrueNAS iSCSI is properly configured prior to connecting
<https://www.truenas.com/docs/scale/25.04/scaleuireference/shares/iscsisharesscreens/>

### NOTE: Please be aware that this plugin uses the TrueNAS APIs but still uses SSH keys

You will still need to configure the SSH connector for listing the ZFS Pools because this is currently being done in a Proxmox module (ZFSPoolPlugin.pm). To configure this please follow the steps at <https://pve.proxmox.com/wiki/Storage:_ZFS_over_iSCSI> that have to do with SSH between Proxmox VE and TrueNAS. The code segment should start out `mkdir /etc/pve/priv/zfs`.

1. Remember to follow the instructions mentioned above for the SSH keys.
2. Refresh the Proxmox GUI in your browser to load the new Javascript code.
3. Add your new TrueNAS ZFS-over-iSCSI storage using the TrueNAS-API.
4. Thanks for your support.

# ****ALPHA**** Custom Plugin with full API support for TrueNAS 25.10  

Included in this repo is an alpha version of a Custom Storage Plugin that uses the newly improved API support in TrueNAS 25.10 which is currently in early stages of testing.

**BOTH PLUGINS CANNOT BE INSTALLED AT THE SAME TIME**

## Installation

```
apt install libio-socket-ip-perl libio-socket-ssl-perl libjson-rpc-common-perl liblog-any-perl libprotocol-websocket-perl
```

```
./deploy.sh
```

## Example config

```
truenas: nas
    blocksize 16k
    iscsiprovider truenas
    pool tank/proxmox
    portal 10.0.0.1
    target iqn.2005-10.org.freenas.ctl:proxmox
    content images
    nowritecache 0
    sparse 1
    truenas_apikey <APIKEY>
    truenas_apiv4_host 10.0.0.1
    truenas_use_ssl 1
    truenas_user <USER>
    truenas_password <PASSWORD>
```
