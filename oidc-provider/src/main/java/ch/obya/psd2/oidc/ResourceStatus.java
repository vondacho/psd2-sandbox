package ch.obya.psd2.oidc;

/**
 * Everything the OIDC-provider is allowed to learn about a consent or a payment.
 *
 * <p>Three fields, and the count is the point. The anticorruption layer exists so that
 * "the OIDC-provider never receives the access object or the PSU" — no {@code access},
 * no {@code psuId}, no {@code validUntil}, no {@code accounts}. A test asserts the arity
 * so that widening this record fails the build rather than quietly leaking the Bank's
 * model across a domain boundary.
 *
 * @param exists whether the named resource is there at all
 * @param ownedByClient whether the requesting client created it
 * @param status the wire form of its status, e.g. {@code received}; an opaque word here
 */
public record ResourceStatus(boolean exists, boolean ownedByClient, String status) {

    /** The answer for a resource that is not there. */
    public static ResourceStatus absent() {
        return new ResourceStatus(false, false, null);
    }

    /** The only status in which a resource may be authorised. */
    public boolean isReceived() {
        return "received".equals(status);
    }
}
