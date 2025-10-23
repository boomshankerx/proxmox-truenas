# TrueNAS over iSCSI

## Acknowledgement

This plugin was made possible by the great work at <https://github.com/TheGrandWazoo/freenas-proxmox>. It has been converted to be compatible with the TrueNAS WebSocket API. It is currently being targeted at Proxmox VE 8+ and TrueNAS 24.10+

## Donations

Thank you for supporting open-source. Made with love for the community.

[![Donate](https://github.com/user-attachments/assets/11a20af8-9bb0-4e42-97a3-35e753b0c8ba)](https://www.paypal.com/donate?hosted_button_id=QZD95HR69R8KA)

## Migrating from freenas-proxmox

1. Choose a node to migrate first and log into the WebUI of that node. Open a shell console
2. `sed -i 's/freenas/truenas/g' /etc/pve/storage.cfg`
3. `apt update && apt full-upgrade`
4. `apt purge freenas-proxmox`
5. `apt --purge autoremove` (freenas-proxmox has installed a perl restclient).
6. `apt reinstall pve-manager libpve-storage-perl`
7. Install proxmox truenas APT repository
8. Install the version of the plugin you intend to use Native or Patch. Please read compatibility carefully
9. Repeat steps 3-7 on each node in the cluster

## Known Issues

### pvesm error
```
400 Result verification failed
config: type check ('object') failed
pvesm add <type> <storage> [OPTIONS]
```
The pvesm command will return the following message but the storage will be added correctly and begin to operate. I'm working with proxmox to troubleshoot the error.

### iSCSI GET_LBA_STATUS and iscsidirect

```
qemu-img: iSCSI GET_LBA_STATUS failed at lba 0: SENSE KEY:ILLEGAL_REQUEST(5) ASCQ:INVALID_FIELD_IN_CDB(0x2400)
```

This is a known warning that occurs during disk migration or backup when using iscsidirect with TrueNAS. It should have no effect on data transfer or integrity. See the discussions below for more information.

https://forum.proxmox.com/threads/lsi-sas2308-scsi-controller-unsupported-sa-0x12.78785/  
https://bugzilla.proxmox.com/show_bug.cgi?id=4046


### TPM Storage  

Proxmox currently doesn't support storing TPM disk on iSCSI LUN. The solution is being discussed here: <https://bugzilla.proxmox.com/show_bug.cgi?id=4693>

#### Workaround (migration without snapshots)

- Create an NFS/SMB share on your proxmox dataset
- Store TPM disks on the NFS/SMB share

## APT Repository

GPG Key

```
curl -fsSL https://boomshankerx.github.io/proxmox-truenas-apt/gpg.key \
  | gpg --dearmor -o /etc/apt/keyrings/proxmox-truenas.gpg
```

[Repository](https://manpages.debian.org/sources.list)

```
. /etc/os-release
cat > /etc/apt/sources.list.d/proxmox-truenas.sources << EOF
Types: deb
URIs: https://boomshankerx.github.io/proxmox-truenas-apt
Suites: $VERSION_CODENAME
Components: main
Signed-By: /etc/apt/keyrings/proxmox-truenas.gpg
EOF
```

# TrueNAS over iSCSI Native Storage Plugin (RC1)

**BOTH VERSIONS OF THIS PLUGIN CANNOT BE INSTALLED AT THE SAME TIME**

## Compatibility

- TrueNAS 25.10+  
- Proxmox VE 8/9

TrueNAS 25.10 has implmented API functionality that supports complete managment of iSCSI disk storage. TrueNAS 25.10 has reached RC1 status

There is currently no Web UI integration for this native plugin. Proxmox has indicated that they are working on the ability for storage plugins to better integrate into the UI in version 9.1. Until then the plugin can be configured in storage.cfg.

## Installation

```
apt update
apt install proxmox-truenas-native
```

## Configuration

### TrueNAS

<https://github.com/boomshankerx/proxmox-truenas/wiki/Configuration-Guide>

### Proxmox

#### pvesm

```
pvesm add truenas truenas \
--blocksize 16k \
--pool tank/proxmox \
--portal 10.0.0.1 \
--target iqn.2005-10.org.freenas.ctl:proxmox \
--shared 1 \
--sparse 1 \
--truenas_apikey <APIKEY> \
--truenas_apiv4_host 10.0.0.1 \
--truenas_use_ssl 1
```

#### Known Bug

The pvesm command will return the following message but the storage will be added correctly and begin to operate. I'm working with proxmox to troubleshoot the error.

```
400 Result verification failed
config: type check ('object') failed
pvesm add <type> <storage> [OPTIONS]
```

#### storage.cfg

```
truenas: truenas
    blocksize 16k
    pool tank/proxmox
    portal 10.0.0.1
    shared 1
    sparse 1
    target iqn.2005-10.org.freenas.ctl:proxmox
    truenas_apikey <APIKEY>
    truenas_apiv4_host 10.0.0.1
    truenas_use_ssl 1
```

# TrueNAS Patch for ZFS over iSCSI (Depricated)

**BOTH VERSIONS OF THIS PLUGIN CANNOT BE INSTALLED AT THE SAME TIME**

## Compatibility

- TrueNAS 24.10 - 25.04
- pve-manager 8.4.14 / 9.0.11  
- libpve-storage-perl 8.3.7 / 9.0.13  

TrueNAS CORE 13.0U6.8 has been reported to work however it is not recommended due to lun limit in ctld  
See: <https://github.com/boomshankerx/proxmox-truenas/issues/56#issuecomment-3315936158>

## Installation

```
apt update
apt install proxmox-truenas
```

## Configuration

### TrueNAS iSCSI

This plugin requires that TrueNAS iSCSI is properly configured prior to connecting
<https://www.truenas.com/docs/scale/25.10/scaletutorials/shares/iscsi/addingiscsishares/#iscsi-manual-setup>

### TrueNAS API Key

<https://www.truenas.com/docs/scale/25.10/scaletutorials/toptoolbar/managingapikeys/>

### SSH Key

You will still need to configure the SSH connector for listing the ZFS Pools because this is currently being done in a Proxmox module (ZFSPoolPlugin.pm). To configure this please follow the steps at <https://pve.proxmox.com/wiki/Storage:_ZFS_over_iSCSI> that have to do with SSH between Proxmox VE and TrueNAS. The code segment should start out `mkdir /etc/pve/priv/zfs`.

1. Remember to follow the instructions mentioned above for the SSH keys.
2. Refresh the Proxmox GUI in your browser to load the new Javascript code.
3. Add your new TrueNAS ZFS-over-iSCSI storage using the TrueNAS-API.
4. Thanks for your support.

### Example Config (/etc/pve/storage.cfg)

Choose: truenas_apikey (Preferred)  OR  truenas_user + truenas_password

```
zfs: truenas
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

## Stargazers over time
[![Stargazers over time](https://starchart.cc/boomshankerx/proxmox-truenas.svg?variant=dark)](https://starchart.cc/boomshankerx/proxmox-truenas)

