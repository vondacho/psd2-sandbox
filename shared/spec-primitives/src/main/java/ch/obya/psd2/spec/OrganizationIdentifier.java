package ch.obya.psd2.spec;

import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * The {@code organizationIdentifier} of an eIDAS certificate subject (OID 2.5.4.97),
 * formatted as ETSI TS 119 495 §5.2.1 requires.
 *
 * <pre>
 *   PSD &lt;2 char country&gt; - &lt;2..8 char NCA id&gt; - &lt;PSP id&gt;
 *   PSDDE-BAFIN-123456
 * </pre>
 *
 * <p>It lives in the shared primitives rather than in one context because three contexts
 * name it: TPP identification derives it from the certificate, consent management stores
 * it as {@code Consent.tppId}, and token issuance uses it as the {@code client_id}.
 * "The organization identifier of the identity is the one in the certificate subject,
 * and it is the client id everywhere else" — {@code tpp-identification.ddm}.
 */
public record OrganizationIdentifier(String value, String country, String ncaId, String pspId) {

    private static final Pattern FORMAT =
            Pattern.compile("^PSD([A-Z]{2})-([A-Z0-9]{2,8})-([A-Za-z0-9_.\\-]{1,64})$");

    public OrganizationIdentifier {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("organizationIdentifier invalid");
        }
    }

    /**
     * Parses and validates.
     *
     * @throws IllegalArgumentException with the message the interface is specified to
     *     return — {@code organizationIdentifier invalid} — for anything that is not in
     *     the ETSI form, such as {@code ACME-123}
     */
    public static OrganizationIdentifier parse(String raw) {
        if (raw == null) {
            throw new IllegalArgumentException("organizationIdentifier invalid");
        }
        Matcher matcher = FORMAT.matcher(raw.trim().toUpperCase(Locale.ROOT));
        if (!matcher.matches()) {
            throw new IllegalArgumentException("organizationIdentifier invalid");
        }
        return new OrganizationIdentifier(
                matcher.group(0), matcher.group(1), matcher.group(2), matcher.group(3));
    }

    /** True when {@code raw} is a well-formed identifier, without throwing. */
    public static boolean isValid(String raw) {
        try {
            parse(raw);
            return true;
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    @Override
    public String toString() {
        return value;
    }
}
