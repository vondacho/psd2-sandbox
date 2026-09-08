package ch.obya.psd2.bank.accounts.domain;

import java.util.List;
import java.util.Optional;

/**
 * An account as the XS2A interface serves it.
 *
 * <p>"An Account here is a resource with an opaque resourceId, projected from the ledger
 * and filtered by one consent; never the ledger's account."
 *
 * <p>So there is no ledger identifier on it beyond the IBAN the TPP is entitled to see,
 * and the {@code resourceId} is the consent's, not the ledger's.
 */
public record AccountResource(
        String resourceId,
        String iban,
        String currency,
        String name,
        String product,
        String cashAccountType,
        String ownerName,
        List<Balance> balances) {

    public AccountResource {
        balances = balances == null ? List.of() : List.copyOf(balances);
    }

    /** The account without its balances, for a call that did not ask for them. */
    public AccountResource withoutBalances() {
        return new AccountResource(resourceId, iban, currency, name, product,
                cashAccountType, ownerName, List.of());
    }

    public Optional<Balance> balanceOf(BalanceType type) {
        return balances.stream().filter(b -> b.type() == type).findFirst();
    }
}
