package ch.obya.psd2.bank.ciam.appl;

import java.util.List;

/**
 * The accounts the consent screen may offer, read from the core banking ledger.
 *
 * <p>Deliberately <strong>conformist</strong>, which is what
 * {@code psd2-access-to-account.ddd} says of this edge: "a read-only list; not worth a
 * translation layer of its own". So the ledger's own words survive — {@code productName},
 * {@code paymentAccount} — where the account information context would have translated
 * them behind an anticorruption layer. The two contexts read the same ledger through
 * different kinds of relationship, and the difference is meant to be visible in the code.
 *
 * <p>The one thing this port does add is the filtering the ledger cannot do: PSD2 access
 * covers payment accounts, and the ledger has no notion of what a consent is.
 */
public interface PaymentAccountDirectory {

    /** Every account of the customer, including the ones a consent may not cover. */
    List<LedgerAccount> accountsOf(String customerId);

    /** One row of the ledger's list, in the ledger's vocabulary. */
    record LedgerAccount(String iban, String currency, String productName,
            boolean paymentAccount) {
    }
}
