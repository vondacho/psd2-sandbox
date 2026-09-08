import { bankById, type BankRegistryEntry } from './registry.js';
import {
  connectionByState, connectionOf, type AccountView, type BankConnection,
} from './connections.js';
import * as xs2a from './xs2a.js';
import { resolveSandboxUrl } from './sandbox-hosts.js';

const clientId = process.env['TPP_CLIENT_ID'] ?? 'PSDDE-BAFIN-123456';
const redirectUri = process.env['TPP_REDIRECT_URI'] ?? 'https://tpp.sandbox/xs2a/callback/bank';

/** A consent valid for the bank's maximum, which the Bank shortens if it is too long. */
const defaultValidUntil = (bank: BankRegistryEntry): string => {
  const until = new Date();
  until.setDate(until.getDate() + bank.maxValidityDays);
  return until.toISOString().slice(0, 10);
};

export interface Started {
  readonly authorizeUrl: string;
}

/**
 * Creates the consent and prepares the redirect.
 *
 * The state and the PKCE verifier are generated here and kept on the connection, never
 * sent to the browser: the callback proves it belongs to this session by matching them.
 */
export const startConnection = async (
  userId: string, bankId: string, psuIpAddress: string | undefined,
): Promise<Started> => {
  const bank = bankById(bankId);
  if (!bank) throw new Error('unknown bank');
  const connection = connectionOf(userId, bankId);

  const consent = await xs2a.createConsent(
    bank.xs2aBaseUrl, redirectUri, psuIpAddress, defaultValidUntil(bank));
  if (consent.status !== 201) {
    connection.state = 'failed';
    connection.lastError = 'BANK_UNREACHABLE';
    throw new Error('BANK_UNREACHABLE');
  }
  const created = consent.body as { consentId: string; _links: Record<string, { href: string }> };
  connection.consentId = created.consentId;
  connection.state = 'consentRequested';

  const authorisations = await xs2a.listAuthorisations(bank.xs2aBaseUrl, created.consentId);
  const authorisationId =
    (authorisations.body as { authorisationIds?: string[] }).authorisationIds?.[0];
  if (authorisationId !== undefined) connection.authorisationId = authorisationId;

  // The scaOAuth link is the Bank telling us where its authorization server lives; we
  // read the metadata from there rather than assuming an endpoint.
  const metadataUrl = resolveSandboxUrl(created._links['scaOAuth']?.href ?? bank.oauthMetadataUrl);
  const metadata = await xs2a.readMetadata(metadataUrl);

  const { verifier, challenge } = xs2a.pkce();
  const state = xs2a.randomState();
  connection.codeVerifier = verifier;
  connection.state_ = state;
  connection.state = 'authorizing';

  // The endpoint comes from the metadata the Bank pointed us at, not from a constant.
  const url = new URL(resolveSandboxUrl(metadata['authorization_endpoint'] ?? ''));
  url.search = new URLSearchParams({
    response_type: 'code',
    client_id: clientId,
    redirect_uri: redirectUri,
    scope: `AIS:${created.consentId} offline_access`,
    state,
    code_challenge: challenge,
    code_challenge_method: 'S256',
    ...(connection.authorisationId ? { authorisation_id: connection.authorisationId } : {}),
  }).toString();
  return { authorizeUrl: url.toString() };
};

/**
 * Handles the redirect back.
 *
 * "Reloading or revisiting the callback repeats nothing": a connection already connected
 * returns its result instead of redeeming the code again, which would fail.
 */
export const completeConnection = async (
  state: string, code: string | undefined, error: string | undefined,
): Promise<BankConnection> => {
  const connection = connectionByState(state);
  if (!connection) throw new Error('STATE_MISMATCH');

  if (connection.state === 'connected') return connection;   // a reload, not a second code
  if (error) {
    connection.state = 'failed';
    connection.lastError = 'ACCESS_NOT_GRANTED';
    return connection;
  }
  if (!code || !connection.codeVerifier) {
    connection.state = 'failed';
    connection.lastError = 'TOKEN_EXCHANGE_FAILED';
    return connection;
  }
  const bank = bankById(connection.bankId)!;
  const metadata = await xs2a.readMetadata(resolveSandboxUrl(bank.oauthMetadataUrl));
  const tokenEndpoint = resolveSandboxUrl(metadata['token_endpoint'] ?? '');

  const tokens = await xs2a.exchangeCode(
    tokenEndpoint, code, redirectUri, connection.codeVerifier, clientId);
  if (tokens.status !== 200) {
    connection.state = 'failed';
    connection.lastError = 'TOKEN_EXCHANGE_FAILED';
    return connection;
  }
  const granted = tokens.body as { access_token: string; refresh_token?: string;
    expires_in: number };
  connection.accessToken = granted.access_token;
  if (granted.refresh_token !== undefined) connection.refreshToken = granted.refresh_token;
  connection.accessExpiresAt = Date.now() + granted.expires_in * 1000;

  const status = await xs2a.readConsentStatus(bank.xs2aBaseUrl, connection.consentId!);
  const consentStatus = (status.body as { consentStatus?: string }).consentStatus;
  if (consentStatus === 'valid') {
    connection.state = 'connected';
    connection.connectedAt = new Date().toISOString();
    // The verifier is spent and goes; the state stays. "Reload after success" must show
    // the success again, and it can only find this connection by its state. Nothing is
    // replayable through it: the early return above sees `connected` and the code has
    // already been redeemed at the OIDC-provider, which refuses it a second time.
    delete connection.codeVerifier;
  } else {
    // "The status is still received right after confirmation" is a real case, not an
    // error: the Bank has the approval and is finishing.
    connection.state = 'authorizing';
    delete connection.lastError;
  }
  return connection;
};

/**
 * The account list, with the cached views returned when the Bank is slow or unhappy.
 *
 * "The cached views are shown while the Bank is slow", and a TOKEN_EXPIRED is invisible
 * to the PSU because it is the TPP's job to refresh, not theirs to understand.
 */
export const accountsOf = async (
  userId: string, bankId: string, psuIpAddress: string | undefined,
): Promise<{ accounts: readonly AccountView[]; stale: boolean; problem?: string }> => {
  const connection = connectionOf(userId, bankId);
  const bank = bankById(bankId);
  if (!bank || connection.state !== 'connected' || !connection.accessToken) {
    return { accounts: [], stale: false, problem: 'CONSENT_INVALID' };
  }
  try {
    const answer = await xs2a.readAccounts(
      bank.xs2aBaseUrl, connection.consentId!, connection.accessToken, psuIpAddress);

    if (answer.status === 200) {
      const fetchedAt = new Date().toISOString();
      const accounts = (answer.body as { accounts: RawAccount[] }).accounts.map(
        (account): AccountView => ({
          resourceId: account.resourceId,
          iban: account.iban,
          currency: account.currency,
          // "displayName preferred over name".
          name: account.displayName ?? account.name ?? account.product ?? 'Account',
          balance: closingBooked(account),
          fetchedAt,
        }));
      connection.accounts = accounts;
      return { accounts, stale: false };
    }
    const code = firstMessageCode(answer.body);
    if (code === 'CONSENT_EXPIRED' || code === 'CONSENT_INVALID') {
      connection.state = 'needsReconsent';
    }
    // Anything else: show what we last knew rather than an empty screen.
    return { accounts: connection.accounts ?? [], stale: true, problem: code ?? 'BANK_UNREACHABLE' };
  } catch {
    return { accounts: connection.accounts ?? [], stale: true, problem: 'BANK_UNREACHABLE' };
  }
};

interface RawAccount {
  resourceId: string; iban: string; currency: string;
  name?: string; displayName?: string; product?: string;
  balances?: { balanceType: string; balanceAmount: { amount: string } }[];
}

const closingBooked = (account: RawAccount): string | null =>
  account.balances?.find((balance) => balance.balanceType === 'closingBooked')
    ?.balanceAmount.amount ?? null;

const firstMessageCode = (body: unknown): string | undefined => {
  const messages = (body as { tppMessages?: { code: string }[] } | null)?.tppMessages;
  return messages?.[0]?.code;
};
