/**
 * The bank registry: which ASPSPs this TPP knows and how to reach them.
 *
 * `bank-connection.ddm` makes this an aggregate of its own — a bank is configuration,
 * not code, so adding one is an entry here and nothing else.
 */
export type ConsentModel = 'bankOffered' | 'dedicated' | 'global' | 'availableAccounts';

export interface BankRegistryEntry {
  readonly bankId: string;
  readonly displayName: string;
  /** Shown on the picker so a PSU recognises their bank before clicking. */
  readonly logo: string;
  readonly xs2aBaseUrl: string;
  readonly oauthMetadataUrl: string;
  readonly consentModels: readonly ConsentModel[];
  readonly requiresSignature: boolean;
  readonly maxValidityDays: number;
}

const registry: readonly BankRegistryEntry[] = [
  {
    bankId: 'bank',
    displayName: 'Sandbox Bank',
    logo: '🏦',
    xs2aBaseUrl: process.env['BANK_XS2A_URL'] ?? 'https://localhost:8443/psd2',
    oauthMetadataUrl:
      process.env['OIDC_METADATA_URL'] ??
      'https://localhost:7443/.well-known/oauth-authorization-server',
    consentModels: ['bankOffered'],
    requiresSignature: false,
    maxValidityDays: 180,
  },
];

export const banks = (): readonly BankRegistryEntry[] => registry;

export const bankById = (bankId: string): BankRegistryEntry | undefined =>
  registry.find((bank) => bank.bankId === bankId);
