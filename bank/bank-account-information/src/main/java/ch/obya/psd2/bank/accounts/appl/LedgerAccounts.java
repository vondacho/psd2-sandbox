package ch.obya.psd2.bank.accounts.appl;

import ch.obya.psd2.bank.accounts.domain.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;

/**
 * The outbound port to the core banking ledger — the anticorruption layer, as an
 * interface.
 *
 * <p>The types crossing it are this context's, not the ledger's: no {@code bookedBalance},
 * no {@code paymentAccount}, no ledger error codes. The adapter behind it is the only
 * code that knows what the ledger calls things, which is what
 * {@code psd2-access-to-account.ddd} means by "the layer exists so the ledger vocabulary
 * never reaches a TPP".
 */
public interface LedgerAccounts {

    /**
     * One account as the ledger currently holds it.
     *
     * <p>The customer comes along because the ledger indexes accounts by customer, and
     * because asking for "this IBAN of that customer" cannot accidentally return an
     * account belonging to someone else.
     *
     * @return empty when the ledger no longer has it — an account closed since the
     *     consent was given still sits in the consent, but must not be served
     */
    Optional<LedgerAccount> byIban(String customerId, String iban, String currency);

    /** What this context needs of a ledger account, in its own words. */
    record LedgerAccount(String iban, String currency, String name, String product,
            String accountType, boolean open, String holderName,
            BigDecimal booked, BigDecimal available, Instant asOf) {

        /** The ledger's two figures, rendered as the XS2A types §14.22 defines. */
        public java.util.List<Balance> asBalances() {
            java.util.List<Balance> balances = new java.util.ArrayList<>();
            if (booked != null) {
                balances.add(new Balance(BalanceType.CLOSING_BOOKED, currency, booked, asOf));
            }
            if (available != null) {
                balances.add(new Balance(
                        BalanceType.INTERIM_AVAILABLE, currency, available, asOf));
            }
            return balances;
        }
    }
}
