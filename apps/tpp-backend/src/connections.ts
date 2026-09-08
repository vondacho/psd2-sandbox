/**
 * The `BankConnection` aggregate: one per (user, bank), holding the consent, the
 * authorisation attempt and the tokens.
 *
 * The state is what the PSU is shown, so it is named for what they would say rather than
 * for what the protocol is doing.
 */
export type ConnectionState =
  | 'selected'
  | 'consentRequested'
  | 'authorizing'
  | 'connected'
  | 'needsReconsent'
  | 'failed';

export interface AccountView {
  readonly resourceId: string;
  readonly iban: string;
  readonly currency: string;
  readonly name: string;
  readonly balance: string | null;
  readonly fetchedAt: string;
}

export interface BankConnection {
  userId: string;
  bankId: string;
  state: ConnectionState;
  consentId?: string;
  authorisationId?: string;
  /** Single-use, bound to the session: the callback is refused if it does not match. */
  state_?: string;
  codeVerifier?: string;
  accessToken?: string;
  refreshToken?: string;
  accessExpiresAt?: number;
  validUntil?: string;
  connectedAt?: string;
  /** Cached so the list can render instantly while the Bank is being asked again. */
  accounts?: readonly AccountView[];
  lastError?: string;
}

const connections = new Map<string, BankConnection>();

const key = (userId: string, bankId: string) => `${userId}|${bankId}`;

export const connectionOf = (userId: string, bankId: string): BankConnection => {
  const existing = connections.get(key(userId, bankId));
  if (existing) return existing;
  const created: BankConnection = { userId, bankId, state: 'selected' };
  connections.set(key(userId, bankId), created);
  return created;
};

export const connectionsOf = (userId: string): readonly BankConnection[] =>
  [...connections.values()].filter((connection) => connection.userId === userId);

/** Looked up by the state parameter on the way back, which is how the callback is bound. */
export const connectionByState = (state: string): BankConnection | undefined =>
  [...connections.values()].find((connection) => connection.state_ === state);

export const forget = (userId: string, bankId: string): void => {
  connections.delete(key(userId, bankId));
};
