# Changelog

## [1.0.104](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.103...v1.0.104) (2025-10-20)


### Bug Fixes

* Add version handling and improve iSCSI LUN management in TrueNAS client ([d77aafc](https://github.com/boomshankerx/proxmox-truenas/commit/d77aafc932dd0c3d68afff058732f6db8b78dd11))

## [1.0.103](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.102...v1.0.103) (2025-10-20)


### Bug Fixes

* Changed delete zvol retry wait time to 1 second ([bbe0a56](https://github.com/boomshankerx/proxmox-truenas/commit/bbe0a56118a39e6f1f80b638e84e1b81ac2e8da2))
* Changed the wrong log message for querying zpool. fixed. ([5ab6d73](https://github.com/boomshankerx/proxmox-truenas/commit/5ab6d73a7ecbb0d79b532a489dbabc8767922809))

## [1.0.102](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.101...v1.0.102) (2025-10-20)


### Bug Fixes

* Made logging for zvol list query debug only. ([c1d4a1f](https://github.com/boomshankerx/proxmox-truenas/commit/c1d4a1f923fac63191b679537c8ee64e7975aec8))
* Reduced APIVER to 11 to support proxmox 8.4 ([5509f42](https://github.com/boomshankerx/proxmox-truenas/commit/5509f423ae733a64a2f65db548725b7f3edce042))

## [1.0.101](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.100...v1.0.101) (2025-10-18)


### Bug Fixes

* Added target validation and default to secure connection ([36c7a76](https://github.com/boomshankerx/proxmox-truenas/commit/36c7a766d26e3c8a58a8548ed3b09e686e4f5563))
* Bump pve-manager to 9.0.11 ([402786c](https://github.com/boomshankerx/proxmox-truenas/commit/402786c304e7867c6d830894c7839cc776c9fca4))

## [1.0.100](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.99...v1.0.100) (2025-10-08)


### Bug Fixes

* Reintroduced replacement of / for - in extent name ([c5888ba](https://github.com/boomshankerx/proxmox-truenas/commit/c5888ba561799a06a87870dd1325fe78c64f2806))
* Removed content option since images is the only option for this plugin ([46b79f1](https://github.com/boomshankerx/proxmox-truenas/commit/46b79f18fd376ee963f3444635ac3cdeec6c8ec4))

## [1.0.99](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.98...v1.0.99) (2025-10-07)


### Bug Fixes

* Added content to native plugin options ([5a6d968](https://github.com/boomshankerx/proxmox-truenas/commit/5a6d96807a1e4f4106322c04763f754c837be764))
* Added default shared option to native plugin. ([96b5665](https://github.com/boomshankerx/proxmox-truenas/commit/96b5665885040d3fa091321bc621d8ddfb46fdd3))
* Default storage to shared in native plugin ([eb4fec6](https://github.com/boomshankerx/proxmox-truenas/commit/eb4fec64aa1f1593dd27f029753b80ff13fc7a3b))

## [1.0.98](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.97...v1.0.98) (2025-10-02)


### Bug Fixes

* Added format to plugindata ([a7a8b44](https://github.com/boomshankerx/proxmox-truenas/commit/a7a8b4431dfcb9694c047772a7a851a618f94a41))

## [1.0.97](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.96...v1.0.97) (2025-09-29)


### Bug Fixes

* Renamed native plugin TrueNASPlugin.pm ([d5a57ff](https://github.com/boomshankerx/proxmox-truenas/commit/d5a57ff294d550d35dfa292330882d9d85b0e73e))

## [1.0.96](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.95...v1.0.96) (2025-09-27)


### Bug Fixes

* Add sleep to prevent race condition during LUN creation ([a0a584d](https://github.com/boomshankerx/proxmox-truenas/commit/a0a584d9cde8854293e5407338b9792a1b0de343))
* Streamline Custom plugin truenas_client_init ([83f5af9](https://github.com/boomshankerx/proxmox-truenas/commit/83f5af902ccbe7b04c46664edcfb025ed60b0980))

## [1.0.95](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.94...v1.0.95) (2025-09-23)


### Bug Fixes

* Fixed progressive retry for deleting busy dataset ([1a52c72](https://github.com/boomshankerx/proxmox-truenas/commit/1a52c72ac4be0d58b190d0e4e191f841c315a786))

## [1.0.94](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.93...v1.0.94) (2025-09-22)


### Bug Fixes

* Changed Handshake failed message to warn ([aceec71](https://github.com/boomshankerx/proxmox-truenas/commit/aceec71011bb450043669947208fb99b26d6a4ab))

## [1.0.93](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.92...v1.0.93) (2025-09-12)


### Bug Fixes

* Added iscsi lun delete in free_image to prevent busy dataset issue ([62a6ced](https://github.com/boomshankerx/proxmox-truenas/commit/62a6ced64badddc2b6fc0da75226b25fc2a10fed))
* Added targetextent lun object to simplfy delete ([2bb3d05](https://github.com/boomshankerx/proxmox-truenas/commit/2bb3d0503456bc1e57859746127ed929e1a397ef))
* Delete targetextent before deleting extent for completness ([facc4d7](https://github.com/boomshankerx/proxmox-truenas/commit/facc4d75a4ef8db34f199c1d3623f7339c64333e))
* fixed bug in zfs_zvol_list ([62a6ced](https://github.com/boomshankerx/proxmox-truenas/commit/62a6ced64badddc2b6fc0da75226b25fc2a10fed))
* Removed array refrence in zfs_zvol_list ([cd8303d](https://github.com/boomshankerx/proxmox-truenas/commit/cd8303d469ba0b73f75a20ace1879bf9ab29f2f4))

## [1.0.92](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.91...v1.0.92) (2025-08-24)


### Bug Fixes

* Fixed v8 patch regression in get_base accepting $scfg ([c661ddd](https://github.com/boomshankerx/proxmox-truenas/commit/c661ddd905774fdbff8ed955289e966f42a1f7d4))

## [1.0.91](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.90...v1.0.91) (2025-08-24)


### Bug Fixes

* Fixed patch regression in get_base accepting $scfg ([3de046d](https://github.com/boomshankerx/proxmox-truenas/commit/3de046d8513b677ce4d39a4a4ef451446cf5c5da))
* Fixed v9 patch regression in get_base accepting $scfg ([1177a46](https://github.com/boomshankerx/proxmox-truenas/commit/1177a4658203d1389b437176847df4f62b6009bc))

## [1.0.90](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.89...v1.0.90) (2025-08-20)


### Bug Fixes

* Increased default timeout to 60 seconds ([19a8e2d](https://github.com/boomshankerx/proxmox-truenas/commit/19a8e2d0d8048fa5d6a5d99c49cfb6ac8d43d3f6))

## [1.0.89](https://github.com/boomshankerx/proxmox-truenas/compare/v1.0.88...v1.0.89) (2025-08-19)


### Bug Fixes

* Changing to versioned releases ([2095b07](https://github.com/boomshankerx/proxmox-truenas/commit/2095b07dd08e17c9790649aeb80715b280031837))
