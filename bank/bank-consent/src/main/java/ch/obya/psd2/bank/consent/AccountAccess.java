package ch.obya.psd2.bank.consent;

import java.util.List;

/**
 * The {@code access} object of a consent request (§14.17).
 *
 * <p>Empty {@code accounts} and {@code balances} arrays mean a <em>bank-offered</em>
 * consent: the PSU picks the accounts at the Bank rather than the TPP naming them. That
 * is the only model the walking skeleton serves; the rest arrive with increment 2.
 */
public record AccountAccess(
        List<AccountReference> accounts,
        List<AccountReference> balances,
        List<AccountReference> transactions,
        String availableAccounts,
        String availableAccountsWithBalance,
        String allPsd2) {

    public AccountAccess {
        accounts = accounts == null ? List.of() : List.copyOf(accounts);
        balances = balances == null ? List.of() : List.copyOf(balances);
        transactions = transactions == null ? List.of() : List.copyOf(transactions);
    }

    /** {@code access {accounts: [], balances: []}} — the bank-offered request. */
    public static AccountAccess bankOffered() {
        return new AccountAccess(List.of(), List.of(), List.of(), null, null, null);
    }

    /** True when the PSU chooses the accounts at the Bank, not the TPP in the request. */
    public boolean isBankOffered() {
        return accounts.isEmpty() && balances.isEmpty() && transactions.isEmpty()
                && availableAccounts == null && availableAccountsWithBalance == null
                && allPsd2 == null;
    }
}
