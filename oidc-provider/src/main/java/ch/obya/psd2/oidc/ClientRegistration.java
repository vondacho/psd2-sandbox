package ch.obya.psd2.oidc;

import ch.obya.psd2.spec.OrganizationIdentifier;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * A TPP as an OAuth2 client: identified by the organization identifier of its QWAC,
 * authenticated by mTLS, allowed to redirect only inside its certificate's domain.
 *
 * @param clientId equals the organizationIdentifier of the bound certificate
 * @param redirectUris matched exactly, except that the host is case-insensitive
 * @param roles read from the QWAC, re-read whenever the certificate rotates
 * @param certificateThumbprints more than one, so certificates can rotate without an outage
 */
public record ClientRegistration(
        OrganizationIdentifier clientId,
        String legalName,
        Set<Psd2Role> roles,
        List<String> redirectUris,
        Set<String> certificateThumbprints) {

    public ClientRegistration {
        roles = Set.copyOf(roles);
        redirectUris = List.copyOf(redirectUris);
        certificateThumbprints = Set.copyOf(certificateThumbprints);
    }

    /**
     * Exact match, with the host compared case-insensitively.
     *
     * <p>"A different path is refused", "an added query parameter is refused",
     * "a different scheme is refused", but "case differs in the host only: accepted".
     */
    public boolean allowsRedirectTo(String candidate) {
        if (candidate == null) {
            return false;
        }
        for (String registered : redirectUris) {
            if (sameUri(registered, candidate)) {
                return true;
            }
        }
        return false;
    }

    private static boolean sameUri(String registered, String candidate) {
        try {
            java.net.URI left = java.net.URI.create(registered);
            java.net.URI right = java.net.URI.create(candidate);
            return equalsIgnoringCase(left.getScheme(), right.getScheme())
                    && equalsIgnoringCase(left.getHost(), right.getHost())
                    && left.getPort() == right.getPort()
                    && java.util.Objects.equals(left.getRawPath(), right.getRawPath())
                    && java.util.Objects.equals(left.getRawQuery(), right.getRawQuery());
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    private static boolean equalsIgnoringCase(String left, String right) {
        return left == null ? right == null
                : left.equalsIgnoreCase(right == null ? null : right.toLowerCase(Locale.ROOT));
    }

    /** True when the connection's certificate is one this client is bound to. */
    public boolean isBoundTo(String thumbprint) {
        return certificateThumbprints.contains(thumbprint);
    }

    public boolean holds(Psd2Role role) {
        return roles.contains(role);
    }
}
