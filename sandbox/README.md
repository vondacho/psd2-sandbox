# Sandbox dependencies

The core banking ledger is **mocked, contract-first**. There is no `bank-core-mock`
module and there should not be one: `psd2-access-to-account.ddd` marks "Accounts ledger"
a generic subdomain, `unmodelled` — "Existing system, wrapped. Nothing inside this
boundary is our model." Writing Java for it would be inventing a model the design says
we do not have.

So the ledger is [`contracts/bank-core-ledger.openapi.yaml`](../contracts/bank-core-ledger.openapi.yaml),
served by [Microcks](https://microcks.io).

## Running it

Rancher Desktop is installed on this machine, so the short path is:

```sh
export PATH="$HOME/.rd/bin:$PATH"     # Rancher's docker is not on the default PATH
docker compose -f sandbox/compose.yaml up -d
```

With podman instead:

```sh
podman machine start
export DOCKER_HOST="unix://$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}')"
podman pull quay.io/curl/curl:latest    # compose's credential helper cannot pull it
podman compose -f sandbox/compose.yaml up -d
```

Both were verified. `up -d` waits for Microcks to become healthy, then imports every
contract; re-running it after editing a contract re-imports it.

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
