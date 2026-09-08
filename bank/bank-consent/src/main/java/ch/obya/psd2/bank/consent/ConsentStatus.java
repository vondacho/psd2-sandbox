package ch.obya.psd2.bank.consent;

/** The seven consent statuses of {@code consent-management.ddm} (NextGenPSD2 §14.15). */
public enum ConsentStatus {
    RECEIVED("received"),
    REJECTED("rejected"),
    PARTIALLY_AUTHORISED("partiallyAuthorised"),
    VALID("valid"),
    EXPIRED("expired"),
    REVOKED_BY_PSU("revokedByPsu"),
    TERMINATED_BY_TPP("terminatedByTpp");

    private final String wireName;

    ConsentStatus(String wireName) {
        this.wireName = wireName;
    }

    public String wireName() {
        return wireName;
    }

    /** Terminal statuses: nothing follows them. */
    public boolean isFinal() {
        return this == REJECTED || this == EXPIRED
                || this == REVOKED_BY_PSU || this == TERMINATED_BY_TPP;
    }
}
