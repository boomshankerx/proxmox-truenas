# TrueNAS ZFS over iSCSI interface 

### 'main' repo (Follows a release branch - Current 2.x) Currently unavailable.

Will be production ready code that has been tested (as best as possible) from the 'testing' repo.

### 'testing' repo (Follows the master branch)

Will be 'beta' code for features, bugs, and updates.

## New Installs.

Issue the following from a command line:

```bash
curl https://ksatechnologies.jfrog.io/artifactory/ksa-repo-gpg/ksatechnologies-release.gpg -o /etc/apt/trusted.gpg.d/ksatechnologies-release.gpg
curl https://ksatechnologies.jfrog.io/artifactory/ksa-repo-gpg/ksatechnologies-repo.list -o /etc/apt/sources.list.d/ksatechnologies-repo.list
```

Then issue the following to install the package

```bash
apt update
apt install proxmox-truenas
```

Then just do your regular upgrade via apt at the command line or the Proxmox Update subsystem; the package will automatically issue all commands to patch the files.

```bash
apt update
apt [full|dist]-upgrade
```

If you wish not to use the package you may remove it at anytime with

```bash
apt [remove|purge] proxmox-truenas
```

This will place you back to a normal and non-patched Proxmox VE install.

#### NOTE: Please be aware that this plugin uses the TrueNAS APIs but still uses SSH keys due to the underlying Proxmox VE perl modules that use the `iscsiadm` command.

You will still need to configure the SSH connector for listing the ZFS Pools because this is currently being done in a Proxmox module (ZFSPoolPlugin.pm). To configure this please follow the steps at https://pve.proxmox.com/wiki/Storage:_ZFS_over_iSCSI that have to do with SSH between Proxmox VE and TrueNAS. The code segment should start out `mkdir /etc/pve/priv/zfs`.

1. Remember to follow the instructions mentioned above for the SSH keys.

2. Refresh the Proxmox GUI in your browser to load the new Javascript code.

3. Add your new TrueNAS ZFS-over-iSCSI storage using the TrueNAS-API.

4. Thanks for your support.
