import { createHash, timingSafeEqual } from 'node:crypto';

export function authorizedDispatch(authorization, secret) {
  if (typeof secret !== 'string' || !secret || typeof authorization !== 'string') return false;
  const digest = (value) => createHash('sha256').update(value).digest();
  return timingSafeEqual(digest(authorization), digest(`Bearer ${secret}`));
}
