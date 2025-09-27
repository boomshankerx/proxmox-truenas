# Changelog

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
