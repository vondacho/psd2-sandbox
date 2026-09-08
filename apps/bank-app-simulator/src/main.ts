import { deviceKeys, loadDevice, publicJwk, rememberEnrolment, sign } from './keystore.js';

/**
 * The Bank's device simulator: what a registered phone does, in a browser.
 *
 * It replaces the native app in the sandbox, and it holds the same guarantee — a
 * non-extractable P-256 key that signs challenges and never leaves.
 *
 * The one screen that matters is the approval screen, and it is built around a single
 * rule: **what is displayed is exactly what the signature will cover**. Anything the
 * PSU has not been shown must not end up inside the signed message, and anything inside
 * the signed message must be on the screen.
 */

interface Challenge {
  challengeId: string;
  status: string;
  expiresAt: string;
  tppName: string;
  summary: string;
  /** `challengeId|nonce|dynamicLinkHash` — precisely what gets signed. */
  message: string;
}

const app = document.getElementById('app')!;
const ciam = location.origin;

const el = (html: string): HTMLElement => {
  const box = document.createElement('div');
  box.innerHTML = html.trim();
  return box.firstElementChild as HTMLElement;
};

const render = (...nodes: HTMLElement[]): void => app.replaceChildren(...nodes);

const secondsLeft = (expiresAt: string): number =>
  Math.max(0, Math.round((new Date(expiresAt).getTime() - Date.now()) / 1000));

// ---- enrolment ------------------------------------------------------------------------

const enrolScreen = async (): Promise<void> => {
  const device = await deviceKeys();
  const jwk = await publicJwk(device.keys);

  const card = el(`
    <section class="card">
      <h2>This device</h2>
      <p class="muted">A P-256 key was created in this browser and stored so it survives a
         reload. The private half is non-extractable — it can sign, and it cannot be read.</p>
      <dl>
        <dt>State</dt><dd>${device.deviceId ? `Enrolled as <code>${device.deviceId}</code>` : '<span class="warn">Not enrolled</span>'}</dd>
        <dt>Public key</dt><dd><code class="jwk">${jwk.kty} ${jwk.crv} x=${(jwk.x ?? '').slice(0, 12)}…</code></dd>
      </dl>
    </section>`);

  render(el('<h1>Bank app</h1>'), card);

  if (!device.deviceId) {
    const form = el(`
      <section class="card">
        <h2>Enrol this device</h2>
        <p class="muted">Your bank links this key to your customer id. It becomes active
           once an existing approval confirms it.</p>
        <label>Customer id <input id="psu" value="anna.mueller" /></label>
      </section>`);
    const enrol = el('<button class="primary">Enrol</button>');
    enrol.addEventListener('click', () => { void doEnrol(device.keys, jwk); });
    form.append(enrol);
    app.append(form);
  }
  app.append(challengeEntry());
};

const doEnrol = async (keys: CryptoKeyPair, jwk: JsonWebKey): Promise<void> => {
  const psuId = (document.getElementById('psu') as HTMLInputElement).value.trim();
  const answer = await fetch(`${ciam}/devices`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      psuId, name: 'Browser simulator', platform: 'web', hardwareBacked: false,
      jwk: { kty: jwk.kty, crv: jwk.crv, x: jwk.x, y: jwk.y },
    }),
  });
  if (!answer.ok) {
    return toast((await answer.json() as { message?: string }).message ?? 'Enrolment refused');
  }
  const { deviceId } = (await answer.json()) as { deviceId: string };
  // The sandbox exposes the confirming SCA directly; a real device would be confirmed
  // by an activation code or an already-active device.
  await fetch(`${ciam}/devices/${deviceId}/activate`, { method: 'POST' });
  await rememberEnrolment(deviceId);
  void enrolScreen();
};

// ---- taking a challenge ---------------------------------------------------------------

const challengeEntry = (): HTMLElement => {
  const card = el(`
    <section class="card">
      <h2>Approve a request</h2>
      <p class="muted">Scan the QR your bank is showing, or paste its payload.</p>
      <label>QR payload <input id="qr" placeholder="https://ciam.bank.sandbox/sca/chl-0001#nonce" /></label>
    </section>`);
  const open = el('<button class="primary">Open request</button>');
  open.addEventListener('click', () => {
    void openChallenge((document.getElementById('qr') as HTMLInputElement).value.trim());
  });
  card.append(open);
  return card;
};

/**
 * Reads the payload, fetches the server's version, and refuses if they disagree.
 *
 * "The app shows the server's details and refuses a QR whose hash disagrees with the
 * server." The nonce in the payload must be the nonce inside the message the server will
 * expect a signature over — otherwise the QR was not the one this challenge issued, and
 * signing it would approve something the PSU never saw.
 */
const openChallenge = async (payload: string): Promise<void> => {
  const match = /\/sca\/([^/#?]+)#(.+)$/.exec(payload);
  if (!match) return toast('That does not look like a challenge from your bank.');
  const [, challengeId, nonce] = match as unknown as [string, string, string];

  const answer = await fetch(`${ciam}/sca/challenges/${challengeId}`);
  if (!answer.ok) return toast('Your bank does not know that request.');
  const challenge = (await answer.json()) as Challenge;

  const [signedId, signedNonce] = challenge.message.split('|');
  if (signedId !== challengeId || signedNonce !== nonce) {
    // Never sign in this case: the QR and the server disagree about what is being
    // approved, and only one of them can be right.
    return toast('This code does not match what your bank is asking. Nothing was approved.');
  }
  if (challenge.status !== 'pending') {
    return toast(`That request is already ${challenge.status}.`);
  }
  approvalScreen(challenge);
};

// ---- the approval screen ---------------------------------------------------------------

const approvalScreen = (challenge: Challenge): void => {
  const left = secondsLeft(challenge.expiresAt);
  const card = el(`
    <section class="card approve">
      <h2>Approve this request?</h2>
      <dl>
        <dt>Who is asking</dt><dd><strong>${challenge.tppName}</strong></dd>
        <dt>What for</dt><dd>${challenge.summary}</dd>
      </dl>
      <p class="countdown" id="countdown">Expires in ${left}s</p>
      <details>
        <summary>What exactly will be signed</summary>
        <code class="signed">${challenge.message}</code>
        <p class="muted">Your device signs this and nothing else. It ties your approval to
           this request, this bank and these accounts.</p>
      </details>
    </section>`);

  const approve = el('<button class="primary">Approve</button>');
  const deny = el('<button class="danger">Deny</button>');
  approve.addEventListener('click', () => { void doApprove(challenge); });
  deny.addEventListener('click', () => { void doDeny(challenge); });
  card.append(approve, deny);
  render(el('<h1>Bank app</h1>'), card);

  const tick = setInterval(() => {
    const remaining = secondsLeft(challenge.expiresAt);
    const countdown = document.getElementById('countdown');
    if (!countdown) return clearInterval(tick);
    countdown.textContent = remaining > 0 ? `Expires in ${remaining}s` : 'This request has expired';
    if (remaining === 0) {
      approve.setAttribute('disabled', 'true');
      clearInterval(tick);
    }
  }, 1000);
};

/** "The simulator signs only after a simulated local verification." */
const localVerification = (): Promise<boolean> =>
  new Promise((resolve) => {
    const sheet = el(`
      <div class="sheet">
        <div class="card">
          <h2>Confirm it is you</h2>
          <p class="muted">On a phone this is Face ID or your PIN. Here, a button.</p>
        </div>
      </div>`);
    const ok = el('<button class="primary">Confirm</button>');
    const cancel = el('<button class="quiet">Cancel</button>');
    ok.addEventListener('click', () => { sheet.remove(); resolve(true); });
    cancel.addEventListener('click', () => { sheet.remove(); resolve(false); });
    sheet.querySelector('.card')!.append(ok, cancel);
    document.body.append(sheet);
  });

const doApprove = async (challenge: Challenge): Promise<void> => {
  const device = await loadDevice();
  if (!device?.deviceId) return toast('Enrol this device first.');
  if (!(await localVerification())) return;

  const signature = await sign(device.keys, challenge.message);
  const answer = await fetch(`${ciam}/sca/challenges/${challenge.challengeId}/response`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: device.deviceId, signature }),
  });
  const body = (await answer.json()) as { status?: string; reason?: string };

  render(el('<h1>Bank app</h1>'), answer.ok
    ? el(`<section class="card done">
            <h2>Approved</h2>
            <p class="muted">Your bank has what it needs. You can close this and go back.</p>
          </section>`)
    : el(`<section class="card"><h2 class="warn">Not approved</h2>
            <p class="muted">${body.reason ?? 'Your bank refused this approval.'}</p></section>`));
  app.append(challengeEntry());
};

const doDeny = async (challenge: Challenge): Promise<void> => {
  await fetch(`${ciam}/sca/challenges/${challenge.challengeId}/deny`, { method: 'POST' });
  render(el('<h1>Bank app</h1>'), el(`
    <section class="card done">
      <h2>Denied</h2>
      <p class="muted">Nothing was shared. You can close this.</p>
    </section>`));
  app.append(challengeEntry());
};

const toast = (message: string): void => {
  const note = el(`<div class="toast">${message}</div>`);
  document.body.append(note);
  setTimeout(() => note.remove(), 5000);
};

void enrolScreen();
