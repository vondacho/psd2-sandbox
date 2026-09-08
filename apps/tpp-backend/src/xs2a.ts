import { readFileSync } from 'node:fs';
import { Agent, request as httpsRequest } from 'node:https';
import { randomUUID, createHash, randomBytes } from 'node:crypto';
import { URL } from 'node:url';

/**
 * The XS2A and OAuth2 client: everything that leaves this process over mTLS.
 *
 * The QWAC is the TPP's identity, so it is presented on every call. Nothing here decides
 * anything about consents; it only speaks the wire format.
 */
const pkiDirectory = process.env['PKI_DIR'] ?? '/tmp/psd2-pki';

const readPki = () => {
  try {
    return {
      cert: readFileSync(`${pkiDirectory}/tpp.pem`),
      key: readFileSync(`${pkiDirectory}/tpp.key`),
      ca: readFileSync(`${pkiDirectory}/ca.pem`),
    };
  } catch {
    return undefined;
  }
};

/** The Bank's server certificate is issued by the sandbox CA, so it is verified. */
const bankAgent = (): Agent => {
  const pki = readPki();
  if (!pki) throw new Error(`no QWAC in ${pkiDirectory} — start bank-xs2a first`);
  return new Agent({ cert: pki.cert, key: pki.key, ca: pki.ca, keepAlive: true });
};

/**
 * The OIDC-provider serves a self-issued certificate: it has no access to the CA's
 * private key, so its server identity cannot be verified here. Its *client*
 * authentication still uses the QWAC, which is what binds the token.
 */
const oidcAgent = (): Agent => {
  const pki = readPki();
  if (!pki) throw new Error(`no QWAC in ${pkiDirectory} — start bank-xs2a first`);
  return new Agent({ cert: pki.cert, key: pki.key, rejectUnauthorized: false, keepAlive: true });
};

export interface Response {
  readonly status: number;
  readonly headers: Record<string, string | string[] | undefined>;
  readonly body: unknown;
}

const send = (
  url: string,
  options: { method: string; headers?: Record<string, string>; body?: string; agent: Agent },
): Promise<Response> =>
  new Promise((resolve, reject) => {
    const target = new URL(url);
    const call = httpsRequest(
      {
        hostname: target.hostname,
        port: target.port,
        path: `${target.pathname}${target.search}`,
        method: options.method,
        headers: options.headers ?? {},
        agent: options.agent,
      },
      (answer) => {
        const chunks: Buffer[] = [];
        answer.on('data', (chunk: Buffer) => chunks.push(chunk));
        answer.on('end', () => {
          const text = Buffer.concat(chunks).toString('utf8');
          let body: unknown = text;
          try {
            body = text.length > 0 ? JSON.parse(text) : null;
          } catch {
            /* a non-JSON body is kept as text so an error page is still legible */
          }
          resolve({ status: answer.statusCode ?? 0, headers: answer.headers, body });
        });
      },
    );
    call.on('error', reject);
    if (options.body !== undefined) call.write(options.body);
    call.end();
  });

/** §4.10: every call carries a fresh X-Request-ID, echoed back for correlation. */
const xs2aHeaders = (extra: Record<string, string> = {}): Record<string, string> => ({
  'X-Request-ID': randomUUID(),
  'Content-Type': 'application/json',
  ...extra,
});

export const createConsent = async (
  xs2aBaseUrl: string,
  redirectUri: string,
  psuIpAddress: string | undefined,
  validUntil: string,
): Promise<Response> =>
  send(`${xs2aBaseUrl}/v1/consents`, {
    method: 'POST',
    agent: bankAgent(),
    headers: xs2aHeaders({
      'TPP-Redirect-URI': redirectUri,
      'TPP-Nok-Redirect-URI': `${redirectUri}?outcome=nok`,
      ...(psuIpAddress ? { 'PSU-IP-Address': psuIpAddress } : {}),
    }),
    // access {accounts: [], balances: []} — bank-offered: the PSU picks at the Bank.
    body: JSON.stringify({
      access: { accounts: [], balances: [] },
      recurringIndicator: true,
      validUntil,
      frequencyPerDay: 4,
    }),
  });

export const readConsentStatus = (xs2aBaseUrl: string, consentId: string): Promise<Response> =>
  send(`${xs2aBaseUrl}/v1/consents/${consentId}/status`, {
    method: 'GET',
    agent: bankAgent(),
    headers: xs2aHeaders(),
  });

export const listAuthorisations = (xs2aBaseUrl: string, consentId: string): Promise<Response> =>
  send(`${xs2aBaseUrl}/v1/consents/${consentId}/authorisations`, {
    method: 'GET',
    agent: bankAgent(),
    headers: xs2aHeaders(),
  });

export const readAccounts = (
  xs2aBaseUrl: string,
  consentId: string,
  accessToken: string,
  psuIpAddress: string | undefined,
): Promise<Response> =>
  send(`${xs2aBaseUrl}/v1/accounts?withBalance=true`, {
    method: 'GET',
    agent: bankAgent(),
    headers: xs2aHeaders({
      'Consent-ID': consentId,
      Authorization: `Bearer ${accessToken}`,
      // §6: with the PSU present the read is not counted against frequencyPerDay.
      ...(psuIpAddress ? { 'PSU-IP-Address': psuIpAddress } : {}),
    }),
  });

export const readMetadata = async (metadataUrl: string): Promise<Record<string, string>> => {
  const answer = await send(metadataUrl, { method: 'GET', agent: oidcAgent() });
  return answer.body as Record<string, string>;
};

export const exchangeCode = (
  tokenEndpoint: string,
  code: string,
  redirectUri: string,
  codeVerifier: string,
  clientId: string,
): Promise<Response> =>
  send(tokenEndpoint, {
    method: 'POST',
    agent: oidcAgent(),
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: redirectUri,
      code_verifier: codeVerifier,
      client_id: clientId,
    }).toString(),
  });

/** RFC 7636 S256. The verifier never leaves this process except at the token endpoint. */
export const pkce = (): { verifier: string; challenge: string } => {
  const verifier = randomBytes(32).toString('base64url');
  return { verifier, challenge: createHash('sha256').update(verifier).digest('base64url') };
};

export const randomState = (): string => randomBytes(24).toString('base64url');
