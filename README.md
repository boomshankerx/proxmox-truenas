# TrueNAS over iSCSI Custom Storage Plugin for Proxmox

## Acknowledgement

This plugin was made possible by the great work at <https://github.com/TheGrandWazoo/freenas-proxmox>. It has been converted to be compatible with the TrueNAS WebSocket API. It is currently being targeted at Proxmox VE 8+ and TrueNAS 24.04+

## Donations

[![Donate](https://img.shields.io/badge/PayPal-Donate-00457C?logo=paypal&logoColor=white)](https://www.paypal.com/donate?hosted_button_id=QZD95HR69R8KA)

Thank you for supporting open-source. Made with love for the community.

## Compatibility

Proxmox VE 8.4.11 / 9.0.10  
pve-manager 8.4.11 / 9.0.10  
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
  | gpg --dearmor -o /etc/apt/keyrings/proxmox-truenas.gpg
```

2. Add the repository

Proxmox 8 / Debian 12 (bookworm):

```
echo "deb [signed-by=/etc/apt/keyrings/proxmox-truenas.gpg] \
https://boomshankerx.github.io/proxmox-truenas-apt bookworm main" \
| tee /etc/apt/sources.list.d/proxmox-truenas.list
```

Proxmox 9 / Debian 13 (trixie):

```
echo "deb [signed-by=/etc/apt/keyrings/proxmox-truenas.gpg] \
https://boomshankerx.github.io/proxmox-truenas-apt trixie main" \
| tee /etc/apt/sources.list.d/proxmox-truenas.list
```

3. Update & install

```
apt update
apt install proxmox-truenas
```

## Manual Installation

1. Download the latest release of the .deb file to your Proxmox host
2. Install the .deb package using `apt install <deb>`
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
    content images
    iscsiprovider truenas
    nowritecache 0
    pool tank/proxmox
    portal 10.0.0.1
    sparse 1
    target iqn.2005-10.org.freenas.ctl:proxmox
    truenas_apikey <APIKEY>
    truenas_apiv4_host 10.0.0.1
    truenas_password <PASSWORD>
    truenas_use_ssl 1
    truenas_user <USER>
```

This plugin requires that TrueNAS iSCSI is properly configured prior to connecting
<https://www.truenas.com/docs/scale/25.04/scaleuireference/shares/iscsisharesscreens/>

### NOTE: Please be aware that this plugin uses the TrueNAS APIs but still uses SSH keys

You will still need to configure the SSH connector for listing the ZFS Pools because this is currently being done in a Proxmox module (ZFSPoolPlugin.pm). To configure this please follow the steps at <https://pve.proxmox.com/wiki/Storage:_ZFS_over_iSCSI> that have to do with SSH between Proxmox VE and TrueNAS. The code segment should start out `mkdir /etc/pve/priv/zfs`.

1. Remember to follow the instructions mentioned above for the SSH keys.
2. Refresh the Proxmox GUI in your browser to load the new Javascript code.
3. Add your new TrueNAS ZFS-over-iSCSI storage using the TrueNAS-API.
4. Thanks for your support.

# ** **BETA** ** TrueNAS over iSCSI Native Storage Plugin for TrueNAS 25.10

Included in this repo is a beta version of a native storage plugin that uses the newly improved API support in TrueNAS 25.10 which is currently in beta testing.

There is currently no Web UI integration for this native plugin. Proxmox has indicated that they are working on the ability for storage plugins to better integrate into the UI in version 9.1. Until then the plugin can be configured in storage.cfg.

**BOTH PLUGINS CANNOT BE INSTALLED AT THE SAME TIME**

## Installation

### APT Repository (Recommended)

1. Import the signing key

```
curl -fsSL https://boomshankerx.github.io/proxmox-truenas-apt/gpg.key \
  | gpg --dearmor -o /etc/apt/keyrings/proxmox-truenas.gpg
```

2. Add the repository

Proxmox 8 / Debian 12 (bookworm):

```
echo "deb [signed-by=/etc/apt/keyrings/proxmox-truenas.gpg] \
https://boomshankerx.github.io/proxmox-truenas-apt bookworm main" \
| tee /etc/apt/sources.list.d/proxmox-truenas.list
```

Proxmox 9 / Debian 13 (trixie):

```
echo "deb [signed-by=/etc/apt/keyrings/proxmox-truenas.gpg] \
https://boomshankerx.github.io/proxmox-truenas-apt trixie main" \
| tee /etc/apt/sources.list.d/proxmox-truenas.list
```

3. Update & install

```
apt update
apt install proxmox-truenas-native
```

### Manual Installation for testing

```
apt install libio-socket-ip-perl libio-socket-ssl-perl libjson-rpc-common-perl liblog-any-perl libprotocol-websocket-perl
```

```
./deploy.sh
```

## Example config

Choose: truenas_apikey (Preferred)  OR  truenas_user + truenas_password

```
truenas: nas
    blocksize 16k
    pool tank/proxmox
    portal 10.0.0.1
    sparse 1
    target iqn.2005-10.org.freenas.ctl:proxmox
    truenas_apikey <APIKEY>
    truenas_apiv4_host 10.0.0.1
    truenas_password <PASSWORD>
    truenas_use_ssl 1
    truenas_user <USER>
```
