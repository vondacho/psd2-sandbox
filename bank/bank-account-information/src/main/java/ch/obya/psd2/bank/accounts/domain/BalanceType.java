package ch.obya.psd2.bank.accounts.domain;

/**
 * The XS2A balance types of §14.22.
 *
 * <p>The ledger knows none of these — it has a booked figure and an available one. Which
 * XS2A type each becomes is a decision of this context, and it is the visible half of the
 * anticorruption layer.
 */
public enum BalanceType {
    CLOSING_BOOKED("closingBooked"),
    EXPECTED("expected"),
    OPENING_BOOKED("openingBooked"),
    INTERIM_AVAILABLE("interimAvailable"),
    INTERIM_BOOKED("interimBooked"),
    FORWARD_AVAILABLE("forwardAvailable"),
    NON_INVOICED("nonInvoiced");

    private final String wireName;

    BalanceType(String wireName) {
        this.wireName = wireName;
    }

    public String wireName() {
        return wireName;
    }
}
