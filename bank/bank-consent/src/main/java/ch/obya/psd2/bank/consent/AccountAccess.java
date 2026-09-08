package ch.obya.psd2.bank.consent;

import java.util.EnumSet;
import java.util.List;
import java.util.Set;

/**
 * The {@code access} object of a consent request (§14.17).
 *
 * <p>A null list and an empty list mean different things here, so neither is normalised
 * away. {@code "accounts": []} is the key <em>present</em> with no accounts named — a
 * bank-offered request for the accounts access type — whereas an absent {@code accounts}
 * key does not ask for that access type at all. That distinction is what decides which
 * access types may later be recorded on an accessible account.
 *
 * <p>Empty {@code accounts} and {@code balances} arrays therefore mean a
 * <em>bank-offered</em> consent: the PSU picks the accounts at the Bank rather than the
 * TPP naming them. That is the only model the walking skeleton serves; the rest arrive
 * with increment 2.
 */
public record AccountAccess(
        List<AccountReference> accounts,
        List<AccountReference> balances,
        List<AccountReference> transactions,
        String availableAccounts,
        String availableAccountsWithBalance,
        String allPsd2) {

    /** {@code access {accounts: [], balances: []}} — the bank-offered request. */
    public static AccountAccess bankOffered() {
        return new AccountAccess(List.of(), List.of(), null, null, null, null);
    }

    /** A request that asks only for the account list, without balances. */
    public static AccountAccess accountsOnly() {
        return new AccountAccess(List.of(), null, null, null, null, null);
    }

    /**
     * The access types this request asks for, from which keys are present.
     *
     * <p>"Access types recorded never exceed the access requested", so this is the
     * ceiling every accessible account is trimmed to.
     */
    public Set<AccessType> requestedTypes() {
        Set<AccessType> types = EnumSet.noneOf(AccessType.class);
        if (accounts != null) {
            types.add(AccessType.ACCOUNTS);
        }
        if (balances != null) {
            types.add(AccessType.BALANCES);
        }
        if (transactions != null) {
            types.add(AccessType.TRANSACTIONS);
        }
        if (availableAccounts != null || availableAccountsWithBalance != null
                || allPsd2 != null) {
            // The all-accounts codes always grant at least the account list.
            types.add(AccessType.ACCOUNTS);
            if (availableAccountsWithBalance != null || allPsd2 != null) {
                types.add(AccessType.BALANCES);
            }
        }
        return types;
    }

    /** True when the PSU chooses the accounts at the Bank, not the TPP in the request. */
    public boolean isBankOffered() {
        return isEmpty(accounts) && isEmpty(balances) && isEmpty(transactions)
                && availableAccounts == null && availableAccountsWithBalance == null
                && allPsd2 == null;
    }

    public List<AccountReference> accountsOrEmpty() {
        return accounts == null ? List.of() : List.copyOf(accounts);
    }

    public List<AccountReference> balancesOrEmpty() {
        return balances == null ? List.of() : List.copyOf(balances);
    }

    public List<AccountReference> transactionsOrEmpty() {
        return transactions == null ? List.of() : List.copyOf(transactions);
    }

    private static boolean isEmpty(List<AccountReference> list) {
        return list == null || list.isEmpty();
    }
}
