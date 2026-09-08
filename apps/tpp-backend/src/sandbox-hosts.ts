/**
 * Resolves the sandbox's hostnames to where they actually listen.
 *
 * The Bank hands out links naming `oidc-provider.sandbox`, as it should — those names are
 * the design's, and a real deployment would resolve them in DNS. On a laptop they do not
 * resolve without editing `/etc/hosts`, so the TPP maps them here instead.
 *
 * This is a deployment concern, not a protocol one: the TPP still *reads* the scaOAuth
 * link the Bank returned rather than assuming an endpoint. Point the variables at real
 * hosts and this becomes the identity function.
 */
const mappings: ReadonlyArray<readonly [string, string]> = [
  ['https://oidc-provider.sandbox', process.env['OIDC_ORIGIN'] ?? 'https://localhost:7443'],
  ['https://api.bank.sandbox/psd2', process.env['BANK_ORIGIN'] ?? 'https://localhost:8443/psd2'],
  ['https://api.bank.sandbox', process.env['BANK_ORIGIN'] ?? 'https://localhost:8443'],
  ['https://ciam.bank.sandbox', process.env['CIAM_ORIGIN'] ?? 'http://localhost:9443'],
];

/**
 * Where the *browser* is sent, which is not always where this process calls.
 *
 * The OIDC-provider's back channel is mTLS on 7443: the token endpoint must be, since the
 * access token is bound to the certificate presented there. Its front channel cannot be —
 * a browser has no QWAC, and a self-signed sandbox certificate would greet the PSU with
 * an interstitial before the journey even starts. So `/authorize` has its own plain-HTTP
 * connector, and only the URL handed to the browser resolves to it.
 *
 * In a real deployment both are the same public HTTPS origin and this list is empty.
 */
const browserMappings: ReadonlyArray<readonly [string, string]> = [
  ['https://oidc-provider.sandbox', process.env['OIDC_BROWSER_ORIGIN'] ?? 'http://localhost:7080'],
];

const resolveWith = (
  table: ReadonlyArray<readonly [string, string]>, url: string,
): string | undefined => {
  for (const [name, actual] of table) {
    if (!url.startsWith(name)) continue;
    // Only rewrite when the name is the whole authority. A plain prefix match would also
    // fire on a URL that already names a port — the mapping adds one of its own, and
    // `https://oidc-provider.sandbox:7443:7443/…` fails as an invalid URL far from here.
    const rest = url.slice(name.length);
    if (rest !== '' && !rest.startsWith('/') && !rest.startsWith('?')) continue;
    return actual + rest;
  }
  return undefined;
};

export const resolveSandboxUrl = (url: string): string => resolveWith(mappings, url) ?? url;

/** Falls back to the back-channel mapping for every host that has no browser variant. */
export const resolveBrowserUrl = (url: string): string =>
  resolveWith(browserMappings, url) ?? resolveSandboxUrl(url);
