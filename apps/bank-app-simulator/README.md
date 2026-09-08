# Device simulator

What a registered phone does, in a browser. §13 calls for "a browser-based device
simulator that scans the QR with the camera or accepts a pasted payload, holds a
WebCrypto key pair, and signs challenges" — it replaces the native app in the sandbox.

Built into `bank-ciam`'s static resources, so it is served by the CIAM itself:

```sh
npm run build
# then, with bank-ciam running:
open http://localhost:9443/simulator/index.html
```

## The key is real

`crypto.subtle.generateKey(..., extractable: false, ...)` and stored as a `CryptoKey` in
IndexedDB — not as bytes. That is the same guarantee a secure enclave gives: the key can
be *used* here and never *taken* from here, by this code or by anything injected into the
page. A reload finds the same key, which is what makes this a device rather than a
session.

## Two rules the screen is built around

**What is displayed is exactly what the signature will cover.** The approval screen shows
the TPP, the purpose and a countdown, and "what exactly will be signed" expands to the
literal message. Nothing the PSU has not been shown ends up inside the signature.

**A QR that disagrees with the server is refused, not signed.** The payload carries
`challengeId#nonce`; the server returns `challengeId|nonce|hash`. If they differ the app
stops — only one of them can be right about what is being approved, and signing would
approve something the PSU never saw.

## The signature format trap

WebCrypto emits the raw `r‖s` pair; Java's `SHA256withECDSA` expects a DER SEQUENCE.
Nothing warns you: the signature is simply wrong and the CIAM answers `BAD_SIGNATURE`.
Measured against the running CIAM:

| Form | Result |
|---|---|
| DER-converted | verified |
| raw `r‖s` | `BAD_SIGNATURE` |

`keystore.ts` converts, and [`verify-against-ciam.mjs`](verify-against-ciam.mjs) keeps
that claim honest against a live CIAM.
