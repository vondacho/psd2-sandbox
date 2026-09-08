package ch.obya.psd2.bank.consent.domain;

/** The opaque handle of a consent. Opaque on purpose: the OIDC-provider only ever sees a string. */
public record ConsentId(String value) {
    public ConsentId {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("consentId must not be blank");
        }
    }

    @Override
    public String toString() {
        return value;
    }
}
