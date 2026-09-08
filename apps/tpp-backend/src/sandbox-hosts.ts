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

export const resolveSandboxUrl = (url: string): string => {
  for (const [name, actual] of mappings) {
    if (url.startsWith(name)) return actual + url.slice(name.length);
  }
  return url;
};
