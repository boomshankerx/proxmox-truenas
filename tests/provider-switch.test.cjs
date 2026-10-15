const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const patchFiles = ['pvemanagerlib.js.8.patch', 'pvemanagerlib.js.9.patch'];

function patchSource(file) {
  const text = fs.readFileSync(path.join(root, 'pve-manager/js', file), 'utf8');
  return text.split('\n')
    .filter(line => !line.startsWith('---') && !line.startsWith('+++') && !line.startsWith('-'))
    .map(line => line.startsWith('+') || line.startsWith(' ') ? line.slice(1) : line)
    .join('\n');
}

function callbackAndReferences(file) {
  const source = patchSource(file);
  const match = source.match(/changeISCSIProvider: (function \(f, newVal, oldVal\) \{[\s\S]*?\n        \}),\n    \},/);
  assert.ok(match, `changeISCSIProvider callback missing in ${file}`);
  const callback = vm.runInNewContext(`(${match[1]})`);
  const references = [...source.matchAll(/reference: '([^']+)'/g)].map(match => match[1]);
  return { callback, references };
}

function fixture(references) {
  const fields = Object.fromEntries(references.map(reference => [reference, {
    value: `configured:${reference}`,
    allowBlank: false,
    setValue(value) { this.value = value; },
  }]));
  const viewModel = { values: {}, set(key, value) { this.values[key] = value; } };
  return {
    fields,
    viewModel,
    getViewModel() { return viewModel; },
    lookupReference(reference) {
      assert.ok(this.fields[reference], `missing reference lookup: ${reference}`);
      return this.fields[reference];
    },
  };
}

for (const patchFile of patchFiles) {
  test(`TrueNAS provider switch enters with configured fields (${patchFile})`, () => {
    const { callback, references } = callbackAndReferences(patchFile);
    const subject = fixture(references);
    callback.call(subject, null, 'truenas', 'comstar');

    assert.equal(subject.viewModel.values.isTrueNAS, true);
    assert.equal(subject.viewModel.values.isComstar, false);
    assert.equal(subject.viewModel.values.hasWriteCacheOption, true);
    assert.equal(subject.fields.truenas_use_ssl_field.value, true);
    for (const reference of ['truenas_apiv4_host_field', 'truenas_user_field',
      'truenas_password_field', 'truenas_confirmpw_field', 'truenas_apikey_field']) {
      assert.match(subject.fields[reference].value, /^configured:/);
    }
    for (const reference of ['truenas_user_field', 'truenas_password_field',
      'truenas_confirmpw_field', 'truenas_apikey_field']) {
      assert.equal(subject.fields[reference].allowBlank, true);
    }
  });

  test(`TrueNAS provider switch leaves with cleared credentials (${patchFile})`, () => {
    const { callback, references } = callbackAndReferences(patchFile);
    const subject = fixture(references);
    callback.call(subject, null, 'comstar', 'truenas');

    assert.equal(subject.viewModel.values.isTrueNAS, false);
    assert.equal(subject.viewModel.values.isComstar, true);
    assert.equal(subject.viewModel.values.hasWriteCacheOption, true);
    assert.equal(subject.fields.truenas_use_ssl_field.value, false);
    for (const reference of ['truenas_apiv4_host_field',
      'truenas_user_field', 'truenas_password_field', 'truenas_confirmpw_field',
      'truenas_apikey_field']) {
      assert.equal(subject.fields[reference].value, '');
    }
    for (const reference of ['truenas_user_field', 'truenas_password_field',
      'truenas_confirmpw_field', 'truenas_apikey_field']) {
      assert.equal(subject.fields[reference].allowBlank, true);
    }
  });
}
