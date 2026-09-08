/**
 * What went wrong, in words a PSU can act on.
 *
 * "A failure shows what happened and what to do, never a blank page." Every failure the
 * journey can produce is listed here with a next step, so no screen has to invent one —
 * and a code the Bank sends that is not listed still gets a sentence rather than a stack
 * trace.
 */
export interface Problem {
  readonly title: string;
  readonly detail: string;
  /** The one thing the PSU can usefully do next. */
  readonly action: { readonly label: string; readonly kind: 'retry' | 'reconnect' | 'back' };
}

const problems: Record<string, Problem> = {
  ACCESS_NOT_GRANTED: {
    title: 'You did not finish at the bank',
    detail: 'Nothing was shared. You can start again whenever you like.',
    action: { label: 'Try connecting again', kind: 'reconnect' },
  },
  TOKEN_EXCHANGE_FAILED: {
    title: 'The bank did not complete the connection',
    detail: 'Your approval was not turned into access. Nothing was shared.',
    action: { label: 'Try connecting again', kind: 'reconnect' },
  },
  BANK_UNREACHABLE: {
    title: 'The bank is not answering',
    detail: 'This is usually brief. Your consent is unaffected.',
    action: { label: 'Try again', kind: 'retry' },
  },
  NO_REGISTERED_DEVICE: {
    title: 'You have no device registered for approvals',
    detail: 'Your bank needs a registered device before it can ask you to approve.',
    action: { label: 'Back to banks', kind: 'back' },
  },
  CONSENT_EXPIRED: {
    title: 'Your consent has expired',
    detail: 'Banks may only share data for a limited time. Reconnecting takes a minute.',
    action: { label: 'Reconnect', kind: 'reconnect' },
  },
  CONSENT_INVALID: {
    title: 'This connection is no longer valid',
    detail: 'The consent was revoked or ended. Reconnect to see your accounts again.',
    action: { label: 'Reconnect', kind: 'reconnect' },
  },
  ACCESS_EXCEEDED: {
    title: "You have reached today's limit",
    detail:
      'Banks limit how often we may read your accounts without you present. This resets tomorrow.',
    action: { label: 'Try again', kind: 'retry' },
  },
  STATE_MISMATCH: {
    title: "That link did not come from here",
    detail: 'For your safety nothing was exchanged. Start the connection again.',
    action: { label: 'Back to banks', kind: 'back' },
  },
};

export const problemFor = (code: string | undefined): Problem =>
  (code !== undefined && problems[code]) || {
    title: 'Something went wrong',
    detail: `The bank reported ${code ?? 'an unexpected error'}. Nothing was shared.`,
    action: { label: 'Try again', kind: 'retry' },
  };
