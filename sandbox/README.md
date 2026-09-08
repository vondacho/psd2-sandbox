# Running the sandbox

Five services make the sandbox, and the journey needs all of them. There are two ways to
start them, and they describe the same topology.

## Everything in containers

```sh
export PATH="$HOME/.rd/bin:$PATH"        # Rancher's docker is not on the default PATH
mvn -DskipTests package                  # the jars the images copy in
npm run build --workspaces               # and the bundled TPP
docker compose -f sandbox/compose.yaml up -d --build
```

Then open **http://localhost:5173**, sign in as Anna, and connect the bank.

| | Where | What it is |
|---|---|---|
| TPP | http://localhost:5173 | the third party: sign in, connect a bank, see accounts |
| Bank sign-in and consent | http://localhost:9443/ui/index.html | reached by redirect, not by hand |
| Device simulator | http://localhost:9443/simulator/index.html | enrol a device, then approve |
| OIDC-provider | http://localhost:7080 (browser), :7443 (mTLS) | two channels, on purpose |
| XS2A API | https://localhost:8443/psd2 | needs a client certificate |
| Microcks console | http://localhost:8585 | the mocked ledger |

Two kinds of address appear in `compose.yaml`, and mixing them up is how this breaks:

- **Between services**, the design's own names — `api.bank.sandbox`, `ciam.bank.sandbox`,
  `oidc-provider.sandbox`, `tpp.sandbox` — which are network aliases here and would be
  DNS in a real deployment. The server certificates carry exactly these names, so mTLS
  verifies the hostname instead of skipping the check.
- **For the browser**, `localhost:<published port>`, because the browser is not on that
  network. Every URL the PSU's browser follows is a localhost one.

## Everything as local processes

Faster to iterate on, and the logs are plain files:

```sh
sdk use java 25.0.2-tem && nvm use --lts
mvn -DskipTests package && npm run build --workspaces
./sandbox/up.sh            # ./sandbox/up.sh down to stop
```

Only the ledger stays a container. Logs land in `/tmp/psd2-logs`.

## Checking it without clicking

`sandbox/journey.mjs` walks the whole journey the way a browser would — following every
redirect by hand, replaying both pages' fetches in order, and signing the challenge with
a real P-256 key from Node's WebCrypto:

```sh
node sandbox/journey.mjs
```

It prints one line per hop and ends with the accounts Anna sees. A failure here is a
failure a person clicking through would also hit.

# The mocked ledger

The core banking ledger is **mocked, contract-first**. There is no `bank-core-mock`
module and there should not be one: `psd2-access-to-account.ddd` marks "Accounts ledger"
a generic subdomain, `unmodelled` — "Existing system, wrapped. Nothing inside this
boundary is our model." Writing Java for it would be inventing a model the design says
we do not have.

So the ledger is [`contracts/bank-core-ledger.openapi.yaml`](../contracts/bank-core-ledger.openapi.yaml),
served by [Microcks](https://microcks.io).

## Running the ledger alone

```sh
docker compose -f sandbox/compose.yaml up -d bank-core bank-core-contracts
```

With podman instead of Rancher:

```sh
podman machine start
export DOCKER_HOST="unix://$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}')"
podman pull quay.io/curl/curl:latest    # compose's credential helper cannot pull it
podman compose -f sandbox/compose.yaml up -d
```

Both were verified. `up -d` waits for Microcks to become healthy, then imports every
contract; re-running it after editing a contract re-imports it.

Two contexts read this mock, through **different kinds of relationship**, and the code
shows the difference on purpose. Account information sits behind an anticorruption layer
(`MicrocksLedgerAccounts` translates every field into its own vocabulary); the CIAM is a
**conformist** (`MicrocksPaymentAccounts` hands the ledger's shape straight through),
because the `.ddd` calls that edge "a read-only list; not worth a translation layer of
its own".

The mock is at `http://localhost:8585/rest/Bank+core+ledger/1.0.0`, and the Microcks UI
at `http://localhost:8585`.

```sh
B=http://localhost:8585/rest/Bank+core+ledger/1.0.0
curl -s $B/customers/anna.mueller/accounts
curl -s $B/accounts/DE23100100100123456789/balances
curl -s $B/accounts/DE23100100100123456789/bookings?from=2026-06-08
```

## How the examples drive the mock

Microcks pairs a request with a response by **matching example names**. The `anna`
example of the `customerId` path parameter selects the `anna` example of the 200
response; `unknown` selects the 404. That is the whole configuration — it derived these
dispatch rules from the contract on import:

| Operation | Dispatcher | Rule |
|---|---|---|
| `GET /customers/{customerId}/accounts` | `URI_PARTS` | `customerId` |
| `GET /accounts/{iban}/balances` | `URI_PARTS` | `iban` |
| `GET /accounts/{iban}/bookings` | `URI_ELEMENTS` | `iban ?? from` |

Adding a case is adding a named example on both sides. No code, no redeploy beyond
re-importing the contract.

## Requiring a bearer token — what works and what does not

The ledger contract declares a `serviceToken` bearer scheme and the Bank's adapter sends
it. Microcks does **not** enforce it yet, and the two obvious routes both fail:

- **`security:` alone is documentation.** Microcks imports it but does not gate on it.
- **A `required: true` Authorization header parameter** is rejected with `400 Parameter
  Authorization is required` *before* dispatch, so it can never produce the contract's
  401 — and Microcks derives its dispatch rules from path and query parameters only, so
  the header is not matched even when present.

The route that does exist is an `x-microcks-operation` **SCRIPT dispatcher** reading the
header. The extension is honoured — Microcks reported `dispatcher=SCRIPT` after import.
It was reverted here because a script whose accessors are wrong **fails silently**:
every request, authenticated or not, fell back to one arbitrary example. A mock that
answers confidently with the wrong account is worse than one that does not check tokens,
so this needs the accessor names pinned down against the Microcks version in use before
it goes back in.

## Making it dynamic later

This is a static mock: fixed responses per named example. Microcks can go further when
the sandbox needs it, and the contract is already the place to say so:

- **Templating** — `{{ request.path[1] }}`, `{{ randomInt(1,100) }}`, `{{ now() }}` in a
  response body, so a balance moves or an `asOf` is genuinely now.
- **`SCRIPT` dispatcher** — a Groovy expression choosing the response, for cases a
  parameter cannot express (a booking list that shrinks as `from` moves).
- **Stateful mocks** — a payment that is `RCVD` on the first read and `ACSC` on the
  second, which is what `move-the-transaction-status-through-its-lifecycle.feature` will
  want.

None of that changes the consumers: the adapter is written against the contract, so the
mock can get cleverer underneath it.
