import assert from 'node:assert/strict';
import test from 'node:test';
import { authorizedDispatch } from '../functions/_shared/hospital_dispatch_auth.mjs';

test('dispatch requires a configured secret and an exact bearer credential', () => {
  assert.equal(authorizedDispatch('Bearer synthetic-secret', 'synthetic-secret'), true);
  for (const header of [null, '', 'synthetic-secret', 'Bearer synthetic-secre',
    'Bearer synthetic-secret-extra', 'bearer synthetic-secret', 'Bearer wrong']) {
    assert.equal(authorizedDispatch(header, 'synthetic-secret'), false);
  }
  for (const secret of [undefined, null, '']) {
    assert.equal(authorizedDispatch('Bearer ', secret), false);
  }
});
