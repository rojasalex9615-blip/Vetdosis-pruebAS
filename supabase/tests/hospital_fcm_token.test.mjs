import assert from 'node:assert/strict';
import test from 'node:test';
import { fcmAccessToken } from '../functions/_shared/hospital_delivery.mjs';

const keys = await crypto.subtle.generateKey({
  name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048,
  publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256',
}, true, ['sign', 'verify']);
const encoded = Buffer.from(await crypto.subtle.exportKey('pkcs8', keys.privateKey)).toString('base64');
const pem = `-----BEGIN PRIVATE KEY-----\n${encoded}\n-----END PRIVATE KEY-----`;
const account = (name) => ({ fcmProject: name, fcmEmail: `${name}@example.test`, fcmKey: pem });

test('a batch reuses token until sixty seconds before provider expiry', async () => {
  let calls = 0;
  let now = 100000;
  const config = account('expiry');
  const fetcher = async (url, options) => {
    calls++;
    assert.equal(url, 'https://oauth2.googleapis.com/token');
    assert.equal(options.body.get('grant_type'), 'urn:ietf:params:oauth:grant-type:jwt-bearer');
    return { ok: true, json: async () => ({ access_token: `synthetic-${calls}`, expires_in: 120 }) };
  };
  assert.equal(await fcmAccessToken(config, fetcher, () => now), 'synthetic-1');
  now += 59000;
  assert.equal(await fcmAccessToken(config, fetcher, () => now), 'synthetic-1');
  now += 1000;
  assert.equal(await fcmAccessToken(config, fetcher, () => now), 'synthetic-2');
  assert.equal(calls, 2);
});

test('email, project and key rotation cannot reuse another configuration token', async () => {
  let calls = 0;
  const fetcher = async () => ({ ok: true, json: async () => ({ access_token: `identity-${++calls}`, expires_in: 3600 }) });
  const config = account('identity');
  assert.equal(await fcmAccessToken(config, fetcher), 'identity-1');
  assert.equal(await fcmAccessToken({ ...config, fcmEmail: 'other@example.test' }, fetcher), 'identity-2');
  assert.equal(await fcmAccessToken({ ...config, fcmProject: 'other' }, fetcher), 'identity-3');
  // Equivalent PEM with different serialization still invalidates the cached identity.
  assert.equal(await fcmAccessToken({ ...config, fcmProject: 'other', fcmKey: `${pem}\n` }, fetcher), 'identity-4');
});

test('missing expiry gets a bounded fallback and failures never become cached tokens', async () => {
  let now = 1000;
  let calls = 0;
  const config = account('fallback');
  const fetcher = async () => ({ ok: true, json: async () => ({ access_token: `fallback-${++calls}` }) });
  assert.equal(await fcmAccessToken(config, fetcher, () => now), 'fallback-1');
  now += 3539000;
  assert.equal(await fcmAccessToken(config, fetcher, () => now), 'fallback-1');
  now += 1000;
  await assert.rejects(fcmAccessToken(config, async () => ({ ok: false }), () => now), /provider_http_error/);
  assert.equal(await fcmAccessToken(config, fetcher, () => now), 'fallback-2');
});
