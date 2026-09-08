/**
 * The Bank's own screens: sign in, choose accounts, approve on your device.
 *
 * Served by the CIAM and never by the TPP, which is the point — the PSU types their
 * password on their bank's page, and the TPP never sees it. The chrome says so on every
 * screen.
 *
 * Plain ES modules over the CIAM's existing JSON endpoints; no build step, so what the
 * Bank serves is what is in the repository.
 */
const app = document.getElementById('app');
const query = new URLSearchParams(location.search);

const context = {
  sessionId: query.get('session_id') ?? '',
  requestId: query.get('request_id') ?? '',
  consentId: query.get('consent_id') ?? '',
  authorisationId: query.get('authorisation_id') ?? '',
  tppName: query.get('tpp_name') ?? 'a third party',
  returnTo: query.get('return_to') ?? '',
  // Filled by the login, not by the query: who the PSU is is the CIAM's answer to give.
  psuId: '',
  amr: [],
};

const el = (html) => {
  const box = document.createElement('div');
  box.innerHTML = html.trim();
  return box.firstElementChild;
};
const render = (...nodes) => app.replaceChildren(...nodes.filter(Boolean));
const groupIban = (iban) => iban.replace(/(.{4})/g, '$1 ').trim();

/** Who is asking, shown on every screen so it cannot be forgotten mid-journey. */
const asking = (what) => el(`
  <div class="asking">
    <div>
      <div class="who">${context.tppName}</div>
      <div class="what">${what}</div>
    </div>
  </div>`);

const post = async (path, body) => {
  const answer = await fetch(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { ok: answer.ok, body: await answer.json().catch(() => ({})) };
};

// ---- 1. sign in ------------------------------------------------------------------

const signIn = (message) => {
  const card = el(`
    <div class="card">
      <label for="psu">Customer id</label>
      <input id="psu" type="text" autocomplete="username" value="anna.mueller" />
      <label for="pwd">Password</label>
      <input id="pwd" type="password" autocomplete="current-password" value="correct horse" />
      ${message ? `<p class="error">${message}</p>` : ''}
    </div>`);
  const go = el('<button class="primary">Sign in</button>');
  const submit = async () => {
    go.disabled = true;
    const result = await post('/login', {
      sessionId: context.sessionId,
      psuId: document.getElementById('psu').value,
      password: document.getElementById('pwd').value,
    });
    go.disabled = false;
    // One message for every failure: a wrong password, an unknown customer and a locked
    // account must be indistinguishable from outside.
    if (!result.ok) return signIn(result.body.message ?? 'Customer id or password is incorrect');
    context.psuId = result.body.psuId;
    context.amr = result.body.amr ?? ['pwd'];
    void chooseAccounts();
  };
  go.addEventListener('click', () => void submit());
  card.addEventListener('keydown', (event) => { if (event.key === 'Enter') void submit(); });
  card.append(go);

  render(
    el('<h1>Sign in to approve</h1>'),
    el('<p class="lede">You are on your bank’s page. Your details are never shown to the app that asked.</p>'),
    asking('wants to see your account information'),
    card,
  );
  setTimeout(() => document.getElementById('psu')?.focus(), 0);
};

// ---- 2. choose the accounts ------------------------------------------------------

/** Filled from the ledger once the PSU is known — never a constant in the page. */
let availableAccounts = [];

const chooseAccounts = async () => {
  const answer = await fetch(`/consent/accounts?sessionId=${encodeURIComponent(context.sessionId)}`);
  availableAccounts = (await answer.json()).accounts ?? [];
  if (availableAccounts.length === 0) {
    return render(el('<h1>No accounts to share</h1>'),
      el('<p class="lede">Your bank has no payment accounts for this customer right now.</p>'));
  }

  const card = el('<div class="card"></div>');
  for (const account of availableAccounts) {
    // A loan is not a payment account, so PSD2 access does not cover it. Showing it
    // greyed out with the reason is clearer than hiding it and leaving the PSU to wonder.
    const row = el(`
      <label class="account ${account.payment ? '' : 'blocked'}">
        <input type="checkbox" value="${account.iban}" data-ccy="${account.currency}"
               ${account.payment ? 'checked' : 'disabled'} />
        <span>
          <span class="name">${account.name}</span><br />
          <span class="iban">${groupIban(account.iban)}</span>
        </span>
        ${account.payment ? '' : '<span class="why">Not a payment account</span>'}
      </label>`);
    card.append(row);
  }

  const go = el('<button class="primary">Share these accounts</button>');
  const cancel = el('<button class="quiet">Cancel</button>');

  const chosen = () => [...card.querySelectorAll('input:checked')].map((box) => ({
    iban: box.value, currency: box.dataset.ccy,
  }));
  const sync = () => { go.disabled = chosen().length === 0; };
  card.addEventListener('change', sync);

  go.addEventListener('click', async () => {
    go.disabled = true;
    await post('/consent/selection', { sessionId: context.sessionId, accounts: chosen() });
    const challenge = await post('/sca/challenges', {
      sessionId: context.sessionId,
      tppId: 'PSDDE-BAFIN-123456',
      validUntil: new Date(Date.now() + 180 * 864e5).toISOString().slice(0, 10),
      summary: `accounts and balances of ${chosen().length} account${chosen().length === 1 ? '' : 's'}`,
    });
    approveOnDevice(challenge.body);
  });
  cancel.addEventListener('click', () => { location.href = `${context.returnTo}?denied=1`; });
  card.append(go, cancel);

  render(
    el('<h1>What may they see?</h1>'),
    el('<p class="lede">Only the accounts you tick. You can change this later by disconnecting.</p>'),
    asking('is asking to read your balances'),
    card,
  );
  sync();
};

// ---- 3. approve on the device ----------------------------------------------------

const approveOnDevice = (challenge) => {
  const card = el(`
    <div class="card">
      <p class="waiting"><span class="tick"></span>Waiting for you to approve on your device</p>
      <img class="qr" alt="Scan this with your bank app" width="220" height="220"
           src="https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${encodeURIComponent(challenge.qr)}" />
      <p class="lede" style="text-align:center">Open the device simulator and scan, or paste this:</p>
      <code class="payload">${challenge.qr}</code>
      <p class="countdown" id="countdown"></p>
    </div>`);
  const open = el('<button class="quiet">Open the device simulator</button>');
  open.addEventListener('click', () => window.open('/simulator/index.html', '_blank'));
  card.append(open);

  render(
    el('<h1>Approve on your device</h1>'),
    el('<p class="lede">Your registered device shows what you are approving and signs it.</p>'),
    asking('is waiting for your approval'),
    card,
  );

  const expiresAt = new Date(challenge.expiresAt).getTime();
  // Poll for the outcome. A real bank would push; the shape the PSU sees is the same.
  const poll = setInterval(async () => {
    const left = Math.max(0, Math.round((expiresAt - Date.now()) / 1000));
    const countdown = document.getElementById('countdown');
    if (countdown) countdown.textContent = left > 0 ? `Expires in ${left}s` : 'This request expired';
    if (left === 0) { clearInterval(poll); return expired(); }

    const status = await (await fetch(`/sca/challenges/${challenge.challengeId}`)).json();
    if (status.status === 'approved') {
      clearInterval(poll);
      // Hand the browser back to the OIDC-provider, which issues the code and sends it
      // on to the TPP. The CIAM never talks to the TPP directly.
      location.href = `${context.returnTo}?request_id=${encodeURIComponent(context.requestId)}`
        + `&sub=${encodeURIComponent(context.psuId)}`
        + `&acr=urn:bank:psd2:sca&amr=${encodeURIComponent(context.amr.join(','))}`;
    } else if (status.status === 'denied') {
      clearInterval(poll);
      render(el('<h1>Not approved</h1>'),
        el('<p class="lede">You denied this on your device. Nothing was shared.</p>'));
    }
  }, 1200);
};

const expired = () => render(
  el('<h1>This request expired</h1>'),
  el('<p class="lede">For your safety approvals are short-lived. Start again from the app.</p>'));

// ---- entry -----------------------------------------------------------------------

if (!context.sessionId) {
  render(el('<h1>Nothing to approve</h1>'),
    el('<p class="lede">Open this page from the app that needs your approval.</p>'));
} else {
  // Tell the CIAM the session exists before the PSU types anything.
  await fetch(`/authorize?session_id=${encodeURIComponent(context.sessionId)}`
    + `&request_id=${encodeURIComponent(context.requestId)}`
    + `&consent_id=${encodeURIComponent(context.consentId)}`
    + `&authorisation_id=${encodeURIComponent(context.authorisationId)}`
    + `&tpp_name=${encodeURIComponent(context.tppName)}`);
  signIn();
}
