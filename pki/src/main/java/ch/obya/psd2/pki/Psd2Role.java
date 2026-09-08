package ch.obya.psd2.pki;

import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;
import org.bouncycastle.asn1.ASN1ObjectIdentifier;

/**
 * The four PSD2 roles of ETSI TS 119 495, with the OIDs under {@code etsi-psd2-roles}
 * ({@code 0.4.0.19495.1}) and the role names that go in the certificate.
 *
 * <p>This is the certificate authority's view, so all four ETSI roles are issuable. The
 * bank's own {@code TppIdentity} model narrows this — a TPP never holds {@code ASPSP} —
 * but that is a domain rule, not a PKI one.
 */
public enum Psd2Role {

    /** Account servicing, {@code PSP_AS}. Held by an ASPSP, not by a TPP. */
    ASPSP("PSP_AS", "1"),
    /** Payment initiation, {@code PSP_PI}. */
    PISP("PSP_PI", "2"),
    /** Account information, {@code PSP_AI}. */
    AISP("PSP_AI", "3"),
    /** Issuing of card-based payment instruments, {@code PSP_IC}. */
    PIISP("PSP_IC", "4");

    /** {@code itu-t(0) identified-organization(4) etsi(0) psd2(19495) roles(1)}. */
    static final ASN1ObjectIdentifier ETSI_PSD2_ROLES = new ASN1ObjectIdentifier("0.4.0.19495.1");

    private final String roleName;
    private final String arc;

    Psd2Role(String roleName, String arc) {
        this.roleName = roleName;
        this.arc = arc;
    }

    /** The {@code RoleOfPSPName}, e.g. {@code PSP_AI}. */
    public String roleName() {
        return roleName;
    }

    /** The {@code RoleOfPspOid}, e.g. {@code 0.4.0.19495.1.3} for {@code PSP_AI}. */
    public ASN1ObjectIdentifier oid() {
        return ETSI_PSD2_ROLES.branch(arc);
    }

    /**
     * Parses the roles of an issuance request.
     *
     * @throws IllegalArgumentException with the message the CLI is specified to print —
     *     {@code unknown role BANK}, or {@code at least one PSD2 role is required}.
     */
    public static Set<Psd2Role> parse(String spec) {
        Set<Psd2Role> roles = new LinkedHashSet<>();
        if (spec != null && !spec.isBlank() && !spec.trim().equalsIgnoreCase("none")) {
            for (String token : spec.trim().split("[\\s,]+")) {
                roles.add(byName(token));
            }
        }
        if (roles.isEmpty()) {
            throw new IllegalArgumentException("at least one PSD2 role is required");
        }
        return roles;
    }

    private static Psd2Role byName(String token) {
        String name = token.toUpperCase(Locale.ROOT);
        for (Psd2Role role : values()) {
            if (role.name().equals(name) || role.roleName.equals(name)) {
                return role;
            }
        }
        throw new IllegalArgumentException("unknown role " + token);
    }
}
