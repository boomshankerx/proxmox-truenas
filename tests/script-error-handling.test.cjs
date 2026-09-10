const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const repo = path.join(__dirname, '..');
const systemPath = '/usr/local/bin:/usr/bin:/bin';

function write(file, data, mode = 0o644) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, data);
  fs.chmodSync(file, mode);
}

function workspace() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'truenas-script-test-'));
  for (const item of ['build.sh', 'deploy.sh', 'perl5', 'pve-manager', 'pve-docs']) {
    fs.cpSync(path.join(repo, item), path.join(dir, item), { recursive: true });
  }
  const deploy = path.join(dir, 'deploy.sh');
  const rewritten = fs.readFileSync(deploy, 'utf8').replaceAll('/usr/share', `${dir}/usr/share`);
  assert.match(rewritten, new RegExp(`PATH_Manager="${dir}/usr/share/`));
  assert.doesNotMatch(rewritten, /PATH_Manager="\/usr\/share\//);
  fs.writeFileSync(deploy, rewritten);
  const bin = path.join(dir, 'bin');
  fs.mkdirSync(bin);
  const wrapper = (command, fallback) => `#!/bin/sh
if [ "${command}" = "$FAIL_COMMAND" ]; then exit 73; fi
exec ${fallback} "$@"
`;
  write(path.join(bin, 'cp'), wrapper('cp', '/bin/cp'), 0o755);
  write(path.join(bin, 'mv'), wrapper('mv', '/bin/mv'), 0o755);
  write(path.join(bin, 'patch'), wrapper('patch', '/usr/bin/patch'), 0o755);
  write(path.join(bin, 'diff'), '#!/bin/sh\ncase "$*" in *pvemanagerlib*) [ "$FAIL_COMMAND" = diff-second ] && exit 73;; esac\nexec /usr/bin/diff "$@"\n', 0o755);
  write(path.join(bin, 'apt'), '#!/bin/sh\n[ "$FAIL_COMMAND" = apt ] && exit 73\nprintf "apt %s\\n" "$*" >> "$COMMAND_LOG"\n', 0o755);
  write(path.join(bin, 'systemctl'), '#!/bin/sh\nprintf "systemctl %s\\n" "$*" >> "$COMMAND_LOG"\n', 0o755);
  write(path.join(bin, 'rsync'), '#!/bin/sh\n[ "$FAIL_COMMAND" = rsync ] && exit 73\nexec /usr/bin/rsync "$@"\n', 0o755);
  write(path.join(bin, 'dpkg-query'), '#!/bin/sh\nver="${PVE_VERSION:-8.0-1}"\ncase "$*" in *pve-manager*) case "$*" in *-f=*) echo "$ver";; *) echo "pve-manager $ver";; esac;; *libpve-storage-perl*) case "$*" in *-f=*) [ "$MISSING_STORAGE" = 1 ] && exit 1; echo "$ver";; *) echo "libpve-storage-perl $ver";; esac;; *proxmox-ve*) echo "proxmox-ve $ver";; esac\n', 0o755);
  return dir;
}

function run(dir, script, args = [], extra = {}) {
  const log = path.join(dir, 'commands.log');
  const env = { ...process.env, ...extra, PATH: `${path.join(dir, 'bin')}:${systemPath}`, COMMAND_LOG: log, TMPDIR: dir };
  const result = spawnSync('/bin/bash', [path.join(dir, script), ...args], {
    cwd: path.join(dir, 'elsewhere'), env, encoding: 'utf8', timeout: 3000,
  });
  assert.ifError(result.error);
  assert.equal(result.signal, null, result.stderr);
  return result;
}

function targetTree(dir) {
  const root = path.join(dir, 'usr/share');
  for (const p of ['pve-manager/js', 'perl5/PVE/Storage', 'perl5/PVE/Storage/Custom', 'perl5/PVE/Storage/LunCmd', 'perl5']) {
    fs.mkdirSync(path.join(root, p), { recursive: true });
  }
  write(path.join(root, 'pve-manager/js/pvemanagerlib.js'), 'manager-old\n');
  write(path.join(root, 'perl5/PVE/Storage/ZFSPlugin.pm'), 'zfs-old\n');
  write(path.join(root, 'perl5/TrueNAS/Helpers.pm'), "log_level => 'info'\n");
  write(path.join(root, 'pve-docs/api-viewer/apidocs.js'), 'docs-old\n');
  return root;
}

function tinyPatch(file, oldText, newText) {
  return `--- a/${file}\n+++ b/${file}\n@@ -1 +1 @@\n-${oldText}+${newText}`;
}

function deployFixture(dir, version = 8) {
  const share = targetTree(dir);
  write(path.join(dir, 'pve-manager/js/pvemanagerlib.js.' + version + '.patch'), tinyPatch('pvemanagerlib.js', 'manager-old\n', 'manager-new\n'));
  write(path.join(dir, 'perl5/PVE/Storage/ZFSPlugin.pm.' + version + '.patch'), tinyPatch('ZFSPlugin.pm', 'zfs-old\n', 'zfs-new\n'));
  write(path.join(share, 'pve-manager/js/pvemanagerlib.js.orig'), 'manager-old\n');
  write(path.join(share, 'perl5/PVE/Storage/ZFSPlugin.pm.orig'), 'zfs-old\n');
  write(path.join(share, 'pve-docs/api-viewer/apidocs.js.orig'), 'docs-backup\n');
  fs.mkdirSync(path.join(dir, 'elsewhere'));
  return share;
}

test('build generates versioned patches from another cwd and publishes both outputs', () => {
  const dir = workspace();
  try {
    fs.mkdirSync(path.join(dir, 'elsewhere'));
    for (const file of ['ZFSPlugin.pm', 'pvemanagerlib.js']) {
      const base = file === 'ZFSPlugin.pm' ? path.join(dir, 'perl5/PVE/Storage') : path.join(dir, 'pve-manager/js');
      write(path.join(base, `${file}.8.orig`), 'old\n');
      write(path.join(base, `${file}.8`), 'new\n');
    }
    const result = run(dir, 'build.sh');
    assert.equal(result.status, 0, result.stderr);
    assert.match(fs.readFileSync(path.join(dir, 'perl5/PVE/Storage/ZFSPlugin.pm.8.patch'), 'utf8'), /new/);
    assert.match(fs.readFileSync(path.join(dir, 'pve-manager/js/pvemanagerlib.js.8.patch'), 'utf8'), /new/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('build preserves both prior outputs when an input is missing or diff fails', () => {
  for (const failure of ['missing', 'diff']) {
    const dir = workspace();
    try {
      fs.mkdirSync(path.join(dir, 'elsewhere'));
      const zfs = path.join(dir, 'perl5/PVE/Storage');
      const manager = path.join(dir, 'pve-manager/js');
      write(path.join(zfs, 'ZFSPlugin.pm.8.orig'), 'old\n');
      write(path.join(manager, 'pvemanagerlib.js.8.orig'), 'old\n');
      write(path.join(zfs, 'ZFSPlugin.pm.8.patch'), 'zfs-sentinel\n');
      write(path.join(manager, 'pvemanagerlib.js.8.patch'), 'manager-sentinel\n');
      if (failure === 'missing') write(path.join(zfs, 'ZFSPlugin.pm.8'), 'new\n');
      else {
        write(path.join(zfs, 'ZFSPlugin.pm.8'), 'new\n');
        write(path.join(manager, 'pvemanagerlib.js.8'), 'new\n');
      }
      const result = run(dir, 'build.sh', [], failure === 'diff' ? { FAIL_COMMAND: 'diff-second' } : {});
      assert.notEqual(result.status, 0);
      assert.equal(fs.readFileSync(path.join(zfs, 'ZFSPlugin.pm.8.patch'), 'utf8'), 'zfs-sentinel\n');
      assert.equal(fs.readFileSync(path.join(manager, 'pvemanagerlib.js.8.patch'), 'utf8'), 'manager-sentinel\n');
    } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  }
});

test('deploy validates flags/resources and native first install without side effects', () => {
  for (const args of [['--unknown'], ['--help']]) {
    const dir = workspace();
    try {
      deployFixture(dir);
      const result = run(dir, 'deploy.sh', args);
      assert.equal(args[0] === '--help' ? result.status : result.status !== 0, args[0] === '--help' ? 0 : true);
      if (args[0] === '--unknown') assert.match(result.stderr, /Unknown argument/);
      assert.equal(fs.existsSync(path.join(dir, 'commands.log')), false);
    } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  }
  const dir = workspace();
  try {
    deployFixture(dir);
    fs.rmSync(path.join(dir, 'pve-manager/js/pvemanagerlib.js.8.patch'));
    const result = run(dir, 'deploy.sh', ['-p']);
    assert.notEqual(result.status, 0);
    assert.equal(fs.readFileSync(path.join(dir, 'usr/share/pve-manager/js/pvemanagerlib.js'), 'utf8'), 'manager-old\n');
    assert.equal(fs.existsSync(path.join(dir, 'commands.log')), false);
    for (const [extra, error] of [[{ PVE_VERSION: '10.0-1' }, /Unsupported pve-manager/],
      [{ MISSING_STORAGE: '1' }, /Cannot query libpve-storage-perl/]]) {
      const preflight = run(dir, 'deploy.sh', ['-p'], extra);
      assert.notEqual(preflight.status, 0);
      assert.match(preflight.stderr, error);
      assert.equal(fs.readFileSync(path.join(dir, 'usr/share/pve-manager/js/pvemanagerlib.js'), 'utf8'), 'manager-old\n');
    }
    for (const file of ['pve-manager/js/pvemanagerlib.js.orig', 'perl5/PVE/Storage/ZFSPlugin.pm.orig', 'pve-docs/api-viewer/apidocs.js.orig']) {
      fs.rmSync(path.join(dir, 'usr/share', file));
    }
    const native = run(dir, 'deploy.sh');
    assert.equal(native.status, 0, native.stderr);
    assert.match(fs.readFileSync(path.join(dir, 'usr/share/perl5/PVE/Storage/Custom/TrueNASPlugin.pm'), 'utf8'), /package/);
    assert.match(fs.readFileSync(path.join(dir, 'commands.log'), 'utf8'), /systemctl restart pvedaemon pvestatd pveproxy/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('deploy patches versions 8 and 9 and stops without restart on failures', () => {
  for (const version of [8, 9]) {
    const dir = workspace();
    try {
      deployFixture(dir, version);
      const result = run(dir, 'deploy.sh', ['-p'], { PVE_VERSION: `${version}.0-1` });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(fs.readFileSync(path.join(dir, 'usr/share/pve-manager/js/pvemanagerlib.js'), 'utf8'), 'manager-new\n');
      assert.doesNotMatch(fs.readFileSync(path.join(dir, 'commands.log'), 'utf8'), /corosync|pve-cluster/);
    } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  }
  {
    const dir = workspace();
    try {
      deployFixture(dir);
      write(path.join(dir, 'pve-manager/js/pvemanagerlib.js.8.patch'), 'not a patch\n');
      const result = run(dir, 'deploy.sh', ['-p']);
      assert.notEqual(result.status, 0);
      assert.equal(fs.readFileSync(path.join(dir, 'usr/share/pve-manager/js/pvemanagerlib.js'), 'utf8'), 'manager-old\n');
      assert.equal(fs.readFileSync(path.join(dir, 'usr/share/perl5/PVE/Storage/ZFSPlugin.pm'), 'utf8'), 'zfs-old\n');
    } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  }
  for (const [args, fail] of [[[], 'cp'], [['-p'], 'patch'], [['-r'], 'apt'], [[], 'rsync']]) {
    const dir = workspace();
    try {
      deployFixture(dir);
      const result = run(dir, 'deploy.sh', args, { FAIL_COMMAND: fail });
      assert.notEqual(result.status, 0);
      assert.ok(!fs.existsSync(path.join(dir, 'commands.log')) || !/systemctl/.test(fs.readFileSync(path.join(dir, 'commands.log'), 'utf8')));
      assert.equal(fs.readFileSync(path.join(dir, 'usr/share/pve-manager/js/pvemanagerlib.js'), 'utf8'), 'manager-old\n');
      assert.equal(fs.readFileSync(path.join(dir, 'usr/share/perl5/PVE/Storage/ZFSPlugin.pm'), 'utf8'), 'zfs-old\n');
      if (fail === 'apt') assert.equal(fs.readFileSync(path.join(dir, 'usr/share/pve-manager/js/pvemanagerlib.js.orig'), 'utf8'), 'manager-old\n');
    } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  }
});
