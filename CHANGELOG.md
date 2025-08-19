# Changelog

## 1.0.0 (2025-08-19)


### Features

* Added orginal and patch src ([8fa52a1](https://github.com/boomshankerx/proxmox-truenas/commit/8fa52a1f0486ee67e3d791a500ee0c242af8a7b8))
* Added TrueNAS::Helpers ([4344a03](https://github.com/boomshankerx/proxmox-truenas/commit/4344a037881a75c372bf0545850b7a937c21ce07))
* Added v9 patches ([2388a96](https://github.com/boomshankerx/proxmox-truenas/commit/2388a96566ccc560a927af27e1d39ea4c47f6322))
* Bashfully added a donate button... ([9bd1c23](https://github.com/boomshankerx/proxmox-truenas/commit/9bd1c23ebc31bf0103b234e23ccb1b530407d367))
* Client updated to support native plugin ([1a24e35](https://github.com/boomshankerx/proxmox-truenas/commit/1a24e35766212225eb4912454205a3cdc055bd0c))
* Client updated to support native plugin ([30607c8](https://github.com/boomshankerx/proxmox-truenas/commit/30607c86c6ccb1d3590976f7f9f62b852ca58de7))
* Moving to versioned patches ([bf8e639](https://github.com/boomshankerx/proxmox-truenas/commit/bf8e639edabaa2be812fec5e30119b65d571fada))
* Started plugin development ([ea18a7f](https://github.com/boomshankerx/proxmox-truenas/commit/ea18a7f70743e7233912a79acfc99f85bafecf35))


### Bug Fixes

* Added 45 second timeout on websocket ([36e3d55](https://github.com/boomshankerx/proxmox-truenas/commit/36e3d550535ab65f4c5719d08ac4f38b8291c686))
* Added reconnect on when socket is closed by timeout ([37611e3](https://github.com/boomshankerx/proxmox-truenas/commit/37611e3cef2de9db619681c3aa9873794e1155bb))
* cleaning up debug files ([9f56927](https://github.com/boomshankerx/proxmox-truenas/commit/9f569278a756a9ea1b5f42c34443c3925aa89093))
* Cleanup ([7b79945](https://github.com/boomshankerx/proxmox-truenas/commit/7b79945003e434e54d92bd502808a670f0f25290))
* cleanup dev scripts ([d1d2fef](https://github.com/boomshankerx/proxmox-truenas/commit/d1d2fef66167b7d5c9d40843a1ab9b7cb15944af))
* Client connection testing is too noisy. Changed ping timer. ([ed9417b](https://github.com/boomshankerx/proxmox-truenas/commit/ed9417be0e8a4173450a5949ddf02876d832f485))
* Client tries to reconnect if the socket is closed due to a long operation ([7b71f54](https://github.com/boomshankerx/proxmox-truenas/commit/7b71f54e4663ff2b2344463a8d07ece8bd659d08))
* client updates and improvments ([f8ead4b](https://github.com/boomshankerx/proxmox-truenas/commit/f8ead4be4f5d5fe7439616b3048b35ffcfe8ab19))
* client updates and improvments ([4981a0f](https://github.com/boomshankerx/proxmox-truenas/commit/4981a0f6560bd7bdf7bb9a37690b4f7387669504))
* Deleting username and password on gui removes from storage.cfg ([7b71f54](https://github.com/boomshankerx/proxmox-truenas/commit/7b71f54e4663ff2b2344463a8d07ece8bd659d08))
* fixed bug in client init failing to switch targets ([fa3bc8f](https://github.com/boomshankerx/proxmox-truenas/commit/fa3bc8f30ea8aa43cdfc05897a1dd98023ca7317))
* fixed bug in client init failing to switch targets ([14f4f09](https://github.com/boomshankerx/proxmox-truenas/commit/14f4f09fa70b9633fefb450d235edefadb53e167))
* Fixed bug in IQN parsing. ([b57f188](https://github.com/boomshankerx/proxmox-truenas/commit/b57f18873103bfafa32667775b225410362accdc))
* Fixed but in how multiple targets are handled. ([377a383](https://github.com/boomshankerx/proxmox-truenas/commit/377a38385a398dae7b8e44204e2397ce395e78c8))
* minor log changes ([fb0fc8d](https://github.com/boomshankerx/proxmox-truenas/commit/fb0fc8d785fc7c07c32b10a6ee9268303b07b9b9))
* missing shift in deply.sh ([613bd63](https://github.com/boomshankerx/proxmox-truenas/commit/613bd63afff25724b3976113bb52c5eaae5eb471))
* Modified on_add_hook to set base_path for truenas ([b5c20cc](https://github.com/boomshankerx/proxmox-truenas/commit/b5c20cc919ab1976928a86430b8aa7d648749fa2))
* More robust connection checking for long operations ([c752609](https://github.com/boomshankerx/proxmox-truenas/commit/c75260997667e324106bf8d8fca779c67a97b11a))
* Moved plugin to Custom folder ([15e07f8](https://github.com/boomshankerx/proxmox-truenas/commit/15e07f82c22bf6f8229a098db8819742fde1d005))
* Redownloaded original files due to _log insertion. ([9cc883a](https://github.com/boomshankerx/proxmox-truenas/commit/9cc883aab1f028652613e30d66401b9c44bd3fcb))
* remove extra debug logging ([92b8172](https://github.com/boomshankerx/proxmox-truenas/commit/92b8172c0cb7f8c60d12a9e14aeb275332a34062))
* Removed _log helper in favor of shared library ([637cdd5](https://github.com/boomshankerx/proxmox-truenas/commit/637cdd59e034852c79db28ef058c46d4cb7ce33a))
* Removed extra debug logging. ([727ee78](https://github.com/boomshankerx/proxmox-truenas/commit/727ee78a1f30dbad11becfaa81ef8ec0ca8565ce))
* removed original files from main branch ([22bde99](https://github.com/boomshankerx/proxmox-truenas/commit/22bde99492c6cb80155995aa2b6812c4dcd8b36b))
* Turn off debugging ([1f56f2b](https://github.com/boomshankerx/proxmox-truenas/commit/1f56f2b809c09a62f04a0565aeb6bec113ed6023))
* Updated Client to use IO::Select for socket timeout. ([7738a4b](https://github.com/boomshankerx/proxmox-truenas/commit/7738a4bf73c101aa07edcdfd1ebf47f7870dfffd))
* Updated deploy script ([ee0ae68](https://github.com/boomshankerx/proxmox-truenas/commit/ee0ae68e9bf7181577f11e2bf6d7584c62c16b87))
* updated deploy.sh to allow chosing patch or plugin ([c7b7ccf](https://github.com/boomshankerx/proxmox-truenas/commit/c7b7ccf7de52d7bc6a49d56a9e3d2b069e053654))
* updated helper scripts for multiversion ([47169a6](https://github.com/boomshankerx/proxmox-truenas/commit/47169a6329e54b163039e243ae3c9255780a4cc9))
* Updated support scripts ([75d911f](https://github.com/boomshankerx/proxmox-truenas/commit/75d911ff003bed047de8a8ec25e5f8c59b725e70))
* v8 patch update ([78538af](https://github.com/boomshankerx/proxmox-truenas/commit/78538afce5983e779295457bba21179bd192d968))
* Various support script updates ([7b71f54](https://github.com/boomshankerx/proxmox-truenas/commit/7b71f54e4663ff2b2344463a8d07ece8bd659d08))
