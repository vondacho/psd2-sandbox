// Proves the simulator's signatures verify in the Bank, using the Bank as the judge.
//
// WebCrypto emits an ECDSA signature as the raw r-then-s pair; Java's SHA256withECDSA
// expects a DER SEQUENCE. Nothing warns you about this -- the signature is simply wrong,
// and the CIAM answers BAD_SIGNATURE with no hint as to why. Measured, on this stack:
//
//     DER-converted  ->  verified
//     raw            ->  BAD_SIGNATURE
//
// So keystore.ts converts, and this script is how that claim stays honest.
//
//     node apps/bank-app-simulator/verify-against-ciam.mjs
//
// with bank-ciam running on 9443. Step 5 reporting anything other than a signature
// failure means the conversion still holds; "approved-but-not-recorded" is expected
// here, because this script invents a consent id the Bank does not have.
const CIAM = 'http://localhost:9443';
const j = async (r) => ({ status: r.status, body: await r.json().catch(() => null) });

const toDer = (raw) => {
  const half = raw.length / 2;
  const trim = (bytes) => {
    let start = 0;
    while (start < bytes.length - 1 && bytes[start] === 0) start++;
    const value = [...bytes.slice(start)];
    return (value[0] & 0x80) !== 0 ? [0, ...value] : value;
  };
  const r = trim(raw.slice(0, half)), s = trim(raw.slice(half));
  const body = [0x02, r.length, ...r, 0x02, s.length, ...s];
  return Buffer.from(Uint8Array.from([0x30, body.length, ...body])).toString('base64url');
};

const keys = await crypto.subtle.generateKey(
  { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign', 'verify']);
const jwk = await crypto.subtle.exportKey('jwk', keys.publicKey);

const enrolled = await j(await fetch(`${CIAM}/devices`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ psuId: 'anna.mueller', name: 'Browser simulator', platform: 'web',
    hardwareBacked: false, jwk: { kty: jwk.kty, crv: jwk.crv, x: jwk.x, y: jwk.y } }) }));
console.log('1. enrolled  ', enrolled.body);
const deviceId = enrolled.body.deviceId;
console.log('2. activated ', (await j(await fetch(`${CIAM}/devices/${deviceId}/activate`, { method: 'POST' }))).body);

await fetch(`${CIAM}/authorize?session_id=sim&request_id=sim&consent_id=c1&authorisation_id=a1&tpp_name=TPP%20App`);
await fetch(`${CIAM}/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ sessionId: 'sim', psuId: 'anna.mueller', password: 'correct horse' }) });
await fetch(`${CIAM}/consent/selection`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ sessionId: 'sim', accounts: [{ iban: 'DE23100100100123456789', currency: 'EUR' }] }) });
const challenge = (await j(await fetch(`${CIAM}/sca/challenges`, { method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ sessionId: 'sim', tppId: 'PSDDE-BAFIN-123456',
    validUntil: '2026-12-05', summary: 'accounts and balances until 2026-12-05' }) }))).body;
console.log('3. challenge ', challenge.challengeId, '| qr:', challenge.qr);

const fetched = (await j(await fetch(`${CIAM}/sca/challenges/${challenge.challengeId}`))).body;
// the cross-check the simulator performs before it will sign anything
const [id, nonce] = fetched.message.split('|');
const fromQr = /\/sca\/([^/#?]+)#(.+)$/.exec(challenge.qr);
console.log('4. QR matches the server:', id === fromQr[1] && nonce === fromQr[2]);

const raw = new Uint8Array(await crypto.subtle.sign(
  { name: 'ECDSA', hash: 'SHA-256' }, keys.privateKey,
  new TextEncoder().encode(fetched.message)));
const answer = await j(await fetch(`${CIAM}/sca/challenges/${challenge.challengeId}/response`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ deviceId, signature: toDer(raw) }) }));
console.log('5. WebCrypto signature accepted by Java:', answer.status, JSON.stringify(answer.body));

// and the raw form, to show the conversion is what makes it work
const answer2 = await j(await fetch(`${CIAM}/sca/challenges/${challenge.challengeId}/response`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ deviceId, signature: Buffer.from(raw).toString('base64url') }) }));
console.log('6. the same signature raw (no DER):', answer2.status, JSON.stringify(answer2.body));
