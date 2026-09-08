/**
 * Plays the whole PSU journey without a browser.
 *
 * Every hop below is one the browser makes: the redirects are followed by hand and the
 * two pages' fetches are replayed in order, so a failure here is a failure a person
 * clicking through would also hit. The device is real — a P-256 key in Node's WebCrypto,
 * signing the same message the simulator signs.
 *
 *   node sandbox/journey.mjs
 */
const TPP = 'http://localhost:5173';
const CIAM = 'http://localhost:9443';

let step = 0;
const say = (what, detail = '') =>
  console.log(`  ${String(++step).padStart(2)}. ${what.padEnd(46)} ${detail}`);
const fail = (what, detail) => { console.error(`\n  FAILED: ${what}\n  ${detail}`); process.exit(1); };

/** A cookie jar, because the TPP's sign-in is a cookie and fetch keeps none. */
let cookie = '';
const call = async (url, init = {}) => {
  const response = await fetch(url, {
    redirect: 'manual',
    ...init,
    headers: { 'Content-Type': 'application/json', ...(cookie && { Cookie: cookie }), ...init.headers },
  });
  const setCookie = response.headers.get('set-cookie');
  if (setCookie) cookie = setCookie.split(';')[0];
  return response;
};
const body = async (response) => {
  const text = await response.text();
  try { return JSON.parse(text); } catch { return text; }
};

console.log('\nThe PSU journey, hop by hop\n');

// ---- the TPP -----------------------------------------------------------------------

const me = await body(await call(`${TPP}/api/signin?userId=anna`, { method: 'POST' }));
if (me.userId !== 'anna') fail('sign in at the TPP', JSON.stringify(me));
say('signed in at the TPP', `as ${me.displayName}`);

const connect = await body(await call(`${TPP}/api/connect?bankId=bank`, { method: 'POST' }));
if (!connect.authorizeUrl) fail('start the connection', JSON.stringify(connect));
say('the TPP created the consent', new URL(connect.authorizeUrl).searchParams.get('scope'));

// ---- the OIDC-provider hands the browser to the bank --------------------------------

const authorize = await call(connect.authorizeUrl);
if (authorize.status !== 302) fail('/authorize should redirect', `${authorize.status} ${await authorize.text()}`);
const consentScreen = new URL(authorize.headers.get('location'));
if (!consentScreen.pathname.startsWith('/ui/')) fail('should land on the bank UI', String(consentScreen));
say('redirected to the bank', consentScreen.pathname);

const q = consentScreen.searchParams;
const context = {
  sessionId: q.get('session_id'), requestId: q.get('request_id'),
  consentId: q.get('consent_id'), authorisationId: q.get('authorisation_id'),
  tppName: q.get('tpp_name'), returnTo: q.get('return_to'),
};
for (const [key, value] of Object.entries(context))
  if (!value) fail('the bank UI needs its context', `${key} is missing from ${consentScreen}`);

// ---- what the bank's page does -------------------------------------------------------

const started = await body(await call(`${CIAM}/authorize?session_id=${context.sessionId}`
  + `&request_id=${context.requestId}&consent_id=${context.consentId}`
  + `&authorisation_id=${context.authorisationId}&tpp_name=${encodeURIComponent(context.tppName)}`));
if (started.step !== 'IDENTIFIED') fail('the CIAM should know the session', JSON.stringify(started));
say('the bank page opened the session', `asking for ${started.tppName}`);

const login = await call(`${CIAM}/login`, { method: 'POST', body: JSON.stringify({
  sessionId: context.sessionId, psuId: 'anna.mueller', password: 'correct horse' }) });
const loggedIn = await body(login);
if (loggedIn.step !== 'FIRST_FACTOR_VERIFIED') fail('log in at the bank', JSON.stringify(loggedIn));
say('the PSU signed in at the bank', `amr ${loggedIn.amr}`);

const offered = await body(await call(`${CIAM}/consent/accounts?sessionId=${context.sessionId}`));
if (!Array.isArray(offered.accounts)) fail('list the accounts to choose from', JSON.stringify(offered));
const payable = offered.accounts.filter((account) => account.payment);
say('the bank offered the accounts',
  `${payable.length} payment, ${offered.accounts.length - payable.length} greyed out`);

const chosen = payable.map(({ iban, currency }) => ({ iban, currency }));
await call(`${CIAM}/consent/selection`, { method: 'POST',
  body: JSON.stringify({ sessionId: context.sessionId, accounts: chosen }) });
say('the PSU chose what to share', chosen.map((a) => a.iban.slice(-4)).join(', '));

const challenge = await body(await call(`${CIAM}/sca/challenges`, { method: 'POST', body: JSON.stringify({
  sessionId: context.sessionId, tppId: 'PSDDE-BAFIN-123456',
  validUntil: new Date(Date.now() + 180 * 864e5).toISOString().slice(0, 10),
  summary: `accounts and balances of ${chosen.length} accounts` }) }));
if (!challenge.challengeId) fail('issue the challenge', JSON.stringify(challenge));
say('the bank issued a challenge', `${challenge.challengeId} (QR shown)`);

// ---- the device ----------------------------------------------------------------------

const key = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign', 'verify']);
const jwk = await crypto.subtle.exportKey('jwk', key.publicKey);
const device = await body(await call(`${CIAM}/devices`, { method: 'POST', body: JSON.stringify({
  psuId: 'anna.mueller', name: "Anna's iPhone", platform: 'iOS', hardwareBacked: true,
  jwk: { kty: jwk.kty, crv: jwk.crv, x: jwk.x, y: jwk.y } }) }));
if (device.status !== 'pending') fail('enrol the device', JSON.stringify(device));
await call(`${CIAM}/devices/${device.deviceId}/activate`, { method: 'POST', body: '{}' });
say('a device enrolled and was activated', device.deviceId);

const toApprove = await body(await call(`${CIAM}/sca/challenges/${challenge.challengeId}`));
if (!toApprove.message) fail('fetch what to approve', JSON.stringify(toApprove));
say('the device fetched what it signs', `"${toApprove.summary}"`);

/** WebCrypto signs raw r‖s; the CIAM verifies DER, as a real device library would emit. */
const raw = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' },
  key.privateKey, new TextEncoder().encode(toApprove.message)));
const half = raw.length / 2;
const trim = (bytes) => {
  let i = 0;
  while (i < bytes.length - 1 && bytes[i] === 0) i += 1;
  const rest = [...bytes.slice(i)];
  return rest[0] & 0x80 ? [0, ...rest] : rest;
};
const r = trim(raw.slice(0, half));
const s = trim(raw.slice(half));
const der = [0x02, r.length, ...r, 0x02, s.length, ...s];
const signature = Buffer.from([0x30, der.length, ...der]).toString('base64url');

const approved = await body(await call(`${CIAM}/sca/challenges/${challenge.challengeId}/response`,
  { method: 'POST', body: JSON.stringify({ deviceId: device.deviceId, signature }) }));
if (approved.status !== 'approved') fail('approve on the device', JSON.stringify(approved));
say('the device approved', `scaStatus ${approved.scaStatus}, consent ${approved.consentStatus}`);

// ---- back to the OIDC-provider, then the TPP -----------------------------------------

const back = await call(`${context.returnTo}?request_id=${encodeURIComponent(context.requestId)}`
  + `&sub=${encodeURIComponent(loggedIn.psuId ?? 'anna.mueller')}`
  + `&acr=urn:bank:psd2:sca&amr=pwd,hwk`);
if (back.status !== 302) fail('the broker should issue a code', `${back.status} ${await back.text()}`);
const callback = new URL(back.headers.get('location'));
if (!callback.searchParams.get('code')) fail('no code in the callback', String(callback));
say('the OIDC-provider issued a code', `→ ${callback.pathname}`);

const tppCallback = await call(`${TPP}${callback.pathname}${callback.search}`);
if (tppCallback.status !== 302) fail('the TPP callback should redirect', String(tppCallback.status));
const landing = tppCallback.headers.get('location');
if (!landing.includes('/connected/')) fail('the connection did not complete', landing);
say('the TPP exchanged the code', landing);

const accounts = await body(await call(`${TPP}/api/accounts?bankId=bank`));
if (!accounts.accounts?.length) fail('read the accounts', JSON.stringify(accounts));
say('the TPP read the accounts', `${accounts.accounts.length} shared`);

console.log('\n  What Anna sees:\n');
for (const account of accounts.accounts)
  console.log(`    ${(account.name ?? account.product ?? 'Account').padEnd(14)}`
    + ` ${account.iban ?? account.maskedPan ?? ''}`.padEnd(28)
    + ` ${account.balance ?? ''} ${account.currency ?? ''}`);
console.log('\n  The journey works end to end.\n');
