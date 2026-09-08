/**
 * The TPP's web app.
 *
 * Four screens and no framework: a bank picker, a waiting state, a confirmation, and the
 * account list. The interesting decisions are not in the rendering but in what the PSU is
 * shown while they wait and when something fails.
 */

interface Bank {
  bankId: string; displayName: string; logo: string;
  state: 'selected' | 'consentRequested' | 'authorizing' | 'connected' | 'needsReconsent' | 'failed';
  connectedAt: string | null; accountCount: number | null;
}

interface Account {
  resourceId: string; iban: string; currency: string; name: string;
  balance: string | null; fetchedAt: string;
}

interface Problem {
  title: string; detail: string;
  action: { label: string; kind: 'retry' | 'reconnect' | 'back' };
}

const app = document.getElementById('app')!;

/** "its IBAN in groups of four" — easier to read aloud, and to compare at a glance. */
const groupIban = (iban: string): string => iban.replace(/(.{4})/g, '$1 ').trim();

const money = (amount: string): string =>
  new Intl.NumberFormat(navigator.language, { minimumFractionDigits: 2 }).format(Number(amount));

const relative = (iso: string): string => {
  const seconds = Math.round((Date.now() - new Date(iso).getTime()) / 1000);
  if (seconds < 45) return 'just now';
  if (seconds < 5400) return `${Math.round(seconds / 60)} min ago`;
  return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
};

const el = (html: string): HTMLElement => {
  const wrapper = document.createElement('div');
  wrapper.innerHTML = html.trim();
  return wrapper.firstElementChild as HTMLElement;
};

const render = (...nodes: (HTMLElement | null)[]): void => {
  app.replaceChildren(...nodes.filter((node): node is HTMLElement => node !== null));
};

interface Me { userId: string | null; displayName?: string; choices?: { id: string; name: string }[]; }

/** The TPP's own sign-in. Deliberately plain: the bank's page is the one that matters. */
const signInScreen = (me: Me): void => {
  const card = el('<div class="card"></div>');
  for (const choice of me.choices ?? []) {
    const row = el(`
      <button class="bank">
        <span class="logo" aria-hidden="true">👤</span>
        <span><span class="name">${choice.name}</span><br />
              <span class="sub">Continue as ${choice.name.split(' ')[0]}</span></span>
        <span class="chev">→</span>
      </button>`);
    row.addEventListener('click', async () => {
      await fetch(`/api/signin?userId=${choice.id}`, { method: 'POST' });
      void route();
    });
    card.append(row);
  }
  render(
    el('<h1>Welcome to TPP App</h1>'),
    el('<p class="lede">All your accounts in one place. Pick a demo profile to begin — this is the app’s own sign-in, not your bank’s.</p>'),
    card,
  );
};

const stateLabel: Record<Bank['state'], { text: string; cls: string }> = {
  selected: { text: 'Not connected', cls: 'pending' },
  consentRequested: { text: 'Starting', cls: 'pending' },
  authorizing: { text: 'Waiting for you', cls: 'pending' },
  connected: { text: 'Connected', cls: 'connected' },
  needsReconsent: { text: 'Needs reconnecting', cls: 'attention' },
  failed: { text: 'Not connected', cls: 'attention' },
};

// ---- screens ------------------------------------------------------------------------

const banksScreen = async (me: Me): Promise<void> => {
  const { banks } = (await (await fetch('/api/banks')).json()) as { banks: Bank[] };

  const list = el('<div class="card"></div>');
  for (const bank of banks) {
    const badge = stateLabel[bank.state];
    const sub = bank.state === 'connected' && bank.accountCount !== null
      ? `${bank.accountCount} account${bank.accountCount === 1 ? '' : 's'} shared`
      : 'Read your balances, nothing else';

    const row = el(`
      <button class="bank">
        <span class="logo" aria-hidden="true">${bank.logo}</span>
        <span>
          <span class="name">${bank.displayName}</span><br />
          <span class="sub">${sub}</span>
        </span>
        <span class="chev"><span class="pill ${badge.cls}">${badge.text}</span></span>
      </button>`);

    row.addEventListener('click', () => {
      if (bank.state === 'connected') {
        location.hash = `#/accounts/${bank.bankId}`;
      } else {
        void connect(bank.bankId);
      }
    });
    list.append(row);
  }

  const signOut = el('<button class="quiet">Sign out</button>');
  signOut.addEventListener('click', async () => {
    await fetch('/api/signout', { method: 'POST' });
    void route();
  });
  const bar = el('<div class="row"></div>');
  bar.append(el(`<span class="asof">Signed in as ${me.displayName ?? ''}</span>`),
    el('<span class="spacer"></span>'), signOut);

  render(
    el('<h1>Your banks</h1>'),
    el('<p class="lede">Connect a bank to see your balances here. You approve each connection at your bank, and you can disconnect at any time.</p>'),
    list,
    bar,
  );
};

const connect = async (bankId: string): Promise<void> => {
  render(
    el('<h1>Taking you to your bank</h1>'),
    el('<p class="lede">You will approve this on your bank’s own page, then come straight back.</p>'),
    skeletonCard(2),
  );
  const answer = await fetch(`/api/connect?bankId=${bankId}`, { method: 'POST' });
  if (!answer.ok) {
    const { problem } = (await answer.json()) as { problem: Problem };
    return problemScreen(problem);
  }
  const { authorizeUrl } = (await answer.json()) as { authorizeUrl: string };
  location.href = authorizeUrl;
};

const connectedScreen = async (bankId: string): Promise<void> => {
  const { accounts } = (await (await fetch(`/api/accounts?bankId=${bankId}`)).json()) as
    { accounts: Account[] };
  const count = accounts.length;

  const card = el(`
    <div class="notice">
      <h2>Your bank is connected</h2>
      <p>${count > 0
        ? `You shared ${count} account${count === 1 ? '' : 's'}. We can read balances until your consent expires.`
        : 'We can read the accounts you shared until your consent expires.'}</p>
    </div>`);
  const go = el('<button class="primary">See my accounts</button>');
  go.addEventListener('click', () => { location.hash = `#/accounts/${bankId}`; });
  card.append(go);
  render(el('<h1>All set</h1>'), card);
};

const accountsScreen = async (bankId: string): Promise<void> => {
  // The cached list is drawn first, so the screen is never empty on a revisit.
  const header = el('<h1>Your accounts</h1>');
  const controls = el('<div class="row"></div>');
  const asOf = el('<span class="asof">Refreshing…</span>');
  const refresh = el('<button class="quiet">Refresh</button>');
  const spacer = el('<span class="spacer"></span>');
  controls.append(asOf, spacer, refresh);

  const card = el('<div class="card"></div>');
  card.append(skeletonRow(), skeletonRow());
  render(header, controls, card);

  const draw = async (): Promise<void> => {
    card.classList.add('stale');
    const result = (await (await fetch(`/api/accounts?bankId=${bankId}`)).json()) as {
      accounts: Account[]; stale: boolean; problem: Problem | null;
    };
    card.classList.remove('stale');
    card.replaceChildren();

    for (const account of result.accounts) {
      const negative = account.balance !== null && Number(account.balance) < 0;
      card.append(el(`
        <div class="account">
          <span>
            <span class="name">${account.name}</span><br />
            <span class="iban">${groupIban(account.iban)}</span>
          </span>
          ${account.balance === null
            ? '<span class="amount none">Balance not shared</span>'
            : `<span class="amount ${negative ? 'negative' : ''}">${money(account.balance)}<span class="ccy">${account.currency}</span></span>`}
        </div>`));
    }
    if (result.accounts.length === 0) {
      card.append(el('<div class="account"><span class="sub">No accounts shared yet.</span></div>'));
    }
    asOf.textContent = result.accounts[0]
      ? `Updated ${relative(result.accounts[0].fetchedAt)}`
      : '';

    // A problem is shown beside the data, not instead of it: yesterday's balance is
    // more useful than an empty screen.
    const existing = document.querySelector('.notice');
    existing?.remove();
    if (result.problem) {
      const notice = el(`
        <div class="notice warn">
          <h2>${result.problem.title}</h2>
          <p>${result.problem.detail}</p>
        </div>`);
      const action = el(`<button class="primary">${result.problem.action.label}</button>`);
      action.addEventListener('click', () => {
        if (result.problem!.action.kind === 'reconnect') void connect(bankId);
        else if (result.problem!.action.kind === 'back') location.hash = '#/banks';
        else void draw();
      });
      notice.append(action);
      card.before(notice);
    }
  };

  refresh.addEventListener('click', () => { void draw(); });
  await draw();
};

const problemScreen = (problem: Problem): void => {
  const notice = el(`
    <div class="notice warn">
      <h2>${problem.title}</h2>
      <p>${problem.detail}</p>
    </div>`);
  const action = el(`<button class="primary">${problem.action.label}</button>`);
  action.addEventListener('click', () => {
    if (problem.action.kind === 'reconnect') void connect('bank');
    else location.hash = '#/banks';
  });
  notice.append(action);
  render(el('<h1>We could not finish</h1>'), notice);
};

const skeletonRow = (): HTMLElement =>
  el('<div class="skeleton"><span class="bar" style="width:9rem"></span><span class="bar" style="width:4rem;margin-left:auto"></span></div>');

const skeletonCard = (rows: number): HTMLElement => {
  const card = el('<div class="card"></div>');
  for (let i = 0; i < rows; i++) card.append(skeletonRow());
  return card;
};

// ---- routing -------------------------------------------------------------------------

const route = async (): Promise<void> => {
  const me = (await (await fetch('/api/me')).json()) as Me;
  if (me.userId === null) return signInScreen(me);

  const [, screen, argument] = location.hash.replace(/^#\//, '').split('/');
  if (screen === 'accounts' && argument) return accountsScreen(argument);
  if (screen === 'connected' && argument) return connectedScreen(argument);
  if (screen === 'problem') {
    const problem = (await (await fetch(`/api/problem/${argument ?? ''}`)).json()) as Problem;
    return problemScreen(problem);
  }
  return banksScreen(me);
};

const start = (): void => {
  if (!location.hash) location.hash = '#/banks';
  void route();
};

window.addEventListener('hashchange', () => { void route(); });
start();
