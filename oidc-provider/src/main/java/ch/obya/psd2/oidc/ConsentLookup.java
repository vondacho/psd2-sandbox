package ch.obya.psd2.oidc;

/**
 * The anticorruption layer to the Bank, as a port.
 *
 * <p>Backed by {@code GET /internal/consents/{id}?client_id={clientId}} — an HTTP call,
 * never an import of {@code bank-consent}. Payment resources are looked up the same way
 * against payment initiation.
 */
@FunctionalInterface
public interface ConsentLookup {

    /**
     * @throws LookupUnavailable when the Bank cannot be reached, which the authorization
     *     endpoint answers with {@code temporarily_unavailable} rather than a refusal
     */
    ResourceStatus lookup(String resourceId, String clientId) throws LookupUnavailable;

    /** Consent management is unreachable — a different answer from "not allowed". */
    class LookupUnavailable extends Exception {
        public LookupUnavailable(String message) {
            super(message);
        }
    }
}
