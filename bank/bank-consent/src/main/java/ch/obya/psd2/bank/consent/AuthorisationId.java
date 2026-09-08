package ch.obya.psd2.bank.consent;

/** The handle of one authorisation sub-resource of a consent (§7). */
public record AuthorisationId(String value) {
    public AuthorisationId {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("authorisationId must not be blank");
        }
    }

    @Override
    public String toString() {
        return value;
    }
}
