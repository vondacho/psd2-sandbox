// src/keystore.ts
var DB = "bank-app-simulator";
var STORE = "device";
var RECORD = "keypair";
var open = () => new Promise((resolve, reject) => {
  const request = indexedDB.open(DB, 1);
  request.onupgradeneeded = () => request.result.createObjectStore(STORE);
  request.onsuccess = () => resolve(request.result);
  request.onerror = () => reject(request.error);
});
var transact = async (mode, run) => {
  const db = await open();
  return new Promise((resolve, reject) => {
    const request = run(db.transaction(STORE, mode).objectStore(STORE));
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
};
var loadDevice = () => transact("readonly", (store) => store.get(RECORD));
var save = (device) => transact("readwrite", (store) => store.put(device, RECORD));
var deviceKeys = async () => {
  const existing = await loadDevice();
  if (existing) return existing;
  const keys = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    // non-extractable: the private half can never leave this browser
    ["sign", "verify"]
  );
  const device = { keys };
  await save(device);
  return device;
};
var rememberEnrolment = async (deviceId) => {
  const device = await deviceKeys();
  await save({ keys: device.keys, deviceId });
};
var publicJwk = async (keys) => crypto.subtle.exportKey("jwk", keys.publicKey);
var sign = async (keys, message) => {
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    keys.privateKey,
    new TextEncoder().encode(message)
  );
  return toDer(new Uint8Array(signature));
};
var toDer = (raw) => {
  const half = raw.length / 2;
  const trim = (bytes) => {
    let start = 0;
    while (start < bytes.length - 1 && bytes[start] === 0) start++;
    const value = [...bytes.slice(start)];
    return (value[0] & 128) !== 0 ? [0, ...value] : value;
  };
  const r = trim(raw.slice(0, half));
  const s = trim(raw.slice(half));
  const body = [2, r.length, ...r, 2, s.length, ...s];
  const der = Uint8Array.from([48, body.length, ...body]);
  return btoa(String.fromCharCode(...der)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

// src/main.ts
var app = document.getElementById("app");
var ciam = location.origin;
var el = (html) => {
  const box = document.createElement("div");
  box.innerHTML = html.trim();
  return box.firstElementChild;
};
var render = (...nodes) => app.replaceChildren(...nodes);
var secondsLeft = (expiresAt) => Math.max(0, Math.round((new Date(expiresAt).getTime() - Date.now()) / 1e3));
var enrolScreen = async () => {
  const device = await deviceKeys();
  const jwk = await publicJwk(device.keys);
  const card = el(`
    <section class="card">
      <h2>This device</h2>
      <p class="muted">A P-256 key was created in this browser and stored so it survives a
         reload. The private half is non-extractable \u2014 it can sign, and it cannot be read.</p>
      <dl>
        <dt>State</dt><dd>${device.deviceId ? `Enrolled as <code>${device.deviceId}</code>` : '<span class="warn">Not enrolled</span>'}</dd>
        <dt>Public key</dt><dd><code class="jwk">${jwk.kty} ${jwk.crv} x=${(jwk.x ?? "").slice(0, 12)}\u2026</code></dd>
      </dl>
    </section>`);
  render(el("<h1>Bank app</h1>"), card);
  if (!device.deviceId) {
    const form = el(`
      <section class="card">
        <h2>Enrol this device</h2>
        <p class="muted">Your bank links this key to your customer id. It becomes active
           once an existing approval confirms it.</p>
        <label>Customer id <input id="psu" value="anna.mueller" /></label>
      </section>`);
    const enrol = el('<button class="primary">Enrol</button>');
    enrol.addEventListener("click", () => {
      void doEnrol(device.keys, jwk);
    });
    form.append(enrol);
    app.append(form);
  }
  app.append(challengeEntry());
};
var doEnrol = async (keys, jwk) => {
  const psuId = document.getElementById("psu").value.trim();
  const answer = await fetch(`${ciam}/devices`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      psuId,
      name: "Browser simulator",
      platform: "web",
      hardwareBacked: false,
      jwk: { kty: jwk.kty, crv: jwk.crv, x: jwk.x, y: jwk.y }
    })
  });
  if (!answer.ok) {
    return toast((await answer.json()).message ?? "Enrolment refused");
  }
  const { deviceId } = await answer.json();
  await fetch(`${ciam}/devices/${deviceId}/activate`, { method: "POST" });
  await rememberEnrolment(deviceId);
  void enrolScreen();
};
var challengeEntry = () => {
  const card = el(`
    <section class="card">
      <h2>Approve a request</h2>
      <p class="muted">Scan the QR your bank is showing, or paste its payload.</p>
      <label>QR payload <input id="qr" placeholder="https://ciam.bank.sandbox/sca/chl-0001#nonce" /></label>
    </section>`);
  const open2 = el('<button class="primary">Open request</button>');
  open2.addEventListener("click", () => {
    void openChallenge(document.getElementById("qr").value.trim());
  });
  card.append(open2);
  return card;
};
var openChallenge = async (payload) => {
  const match = /\/sca\/([^/#?]+)#(.+)$/.exec(payload);
  if (!match) return toast("That does not look like a challenge from your bank.");
  const [, challengeId, nonce] = match;
  const answer = await fetch(`${ciam}/sca/challenges/${challengeId}`);
  if (!answer.ok) return toast("Your bank does not know that request.");
  const challenge = await answer.json();
  const [signedId, signedNonce] = challenge.message.split("|");
  if (signedId !== challengeId || signedNonce !== nonce) {
    return toast("This code does not match what your bank is asking. Nothing was approved.");
  }
  if (challenge.status !== "pending") {
    return toast(`That request is already ${challenge.status}.`);
  }
  approvalScreen(challenge);
};
var approvalScreen = (challenge) => {
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
  approve.addEventListener("click", () => {
    void doApprove(challenge);
  });
  deny.addEventListener("click", () => {
    void doDeny(challenge);
  });
  card.append(approve, deny);
  render(el("<h1>Bank app</h1>"), card);
  const tick = setInterval(() => {
    const remaining = secondsLeft(challenge.expiresAt);
    const countdown = document.getElementById("countdown");
    if (!countdown) return clearInterval(tick);
    countdown.textContent = remaining > 0 ? `Expires in ${remaining}s` : "This request has expired";
    if (remaining === 0) {
      approve.setAttribute("disabled", "true");
      clearInterval(tick);
    }
  }, 1e3);
};
var localVerification = () => new Promise((resolve) => {
  const sheet = el(`
      <div class="sheet">
        <div class="card">
          <h2>Confirm it is you</h2>
          <p class="muted">On a phone this is Face ID or your PIN. Here, a button.</p>
        </div>
      </div>`);
  const ok = el('<button class="primary">Confirm</button>');
  const cancel = el('<button class="quiet">Cancel</button>');
  ok.addEventListener("click", () => {
    sheet.remove();
    resolve(true);
  });
  cancel.addEventListener("click", () => {
    sheet.remove();
    resolve(false);
  });
  sheet.querySelector(".card").append(ok, cancel);
  document.body.append(sheet);
});
var doApprove = async (challenge) => {
  const device = await loadDevice();
  if (!device?.deviceId) return toast("Enrol this device first.");
  if (!await localVerification()) return;
  const signature = await sign(device.keys, challenge.message);
  const answer = await fetch(`${ciam}/sca/challenges/${challenge.challengeId}/response`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ deviceId: device.deviceId, signature })
  });
  const body = await answer.json();
  render(el("<h1>Bank app</h1>"), answer.ok ? el(`<section class="card done">
            <h2>Approved</h2>
            <p class="muted">Your bank has what it needs. You can close this and go back.</p>
          </section>`) : el(`<section class="card"><h2 class="warn">Not approved</h2>
            <p class="muted">${body.reason ?? "Your bank refused this approval."}</p></section>`));
  app.append(challengeEntry());
};
var doDeny = async (challenge) => {
  await fetch(`${ciam}/sca/challenges/${challenge.challengeId}/deny`, { method: "POST" });
  render(el("<h1>Bank app</h1>"), el(`
    <section class="card done">
      <h2>Denied</h2>
      <p class="muted">Nothing was shared. You can close this.</p>
    </section>`));
  app.append(challengeEntry());
};
var toast = (message) => {
  const note = el(`<div class="toast">${message}</div>`);
  document.body.append(note);
  setTimeout(() => note.remove(), 5e3);
};
void enrolScreen();
