package ch.obya.psd2.bank.tpp.domain;

import java.util.Locale;
import java.util.Optional;

/**
 * The PSD2 roles a TPP can hold, as ETSI TS 119 495 names them in the certificate.
 *
 * <p>Three, not four. The context map's language list for TPP identification reads
 * {@code "PSD2 role" "AISP" "PISP" "PIISP"}, and {@code token-issuance.ddm} agrees.
 * {@code tpp-identification.ddm} additionally lists {@code "ASPSP"}, which is drift:
 * ASPSP is a role of the bank's own identity, never of a {@code TppIdentity}. The
 * {@code .ddm} still needs that one-line correction.
 *
 * <p>The CA in the {@code pki} module knows all four, because ETSI defines all four —
 * that is a PKI concern, not a domain one.
 */
public enum Psd2Role {

    /** Account information. {@code PSP_AI}, {@code 0.4.0.19495.1.3}. */
    AISP("PSP_AI", "0.4.0.19495.1.3"),
    /** Payment initiation. {@code PSP_PI}, {@code 0.4.0.19495.1.2}. */
    PISP("PSP_PI", "0.4.0.19495.1.2"),
    /** Card-based payment instrument issuing. {@code PSP_IC}, {@code 0.4.0.19495.1.4}. */
    PIISP("PSP_IC", "0.4.0.19495.1.4");

    private final String roleName;
    private final String oid;

    Psd2Role(String roleName, String oid) {
        this.roleName = roleName;
        this.oid = oid;
    }

    public String roleName() {
        return roleName;
    }

    public String oid() {
        return oid;
    }

    /** Resolves a role from its certificate OID, ignoring roles a TPP cannot hold. */
    public static Optional<Psd2Role> byOid(String oid) {
        for (Psd2Role role : values()) {
            if (role.oid.equals(oid)) {
                return Optional.of(role);
            }
        }
        return Optional.empty();
    }

    /** Resolves a role from its ETSI name, e.g. {@code PSP_AI}. */
    public static Optional<Psd2Role> byRoleName(String name) {
        String upper = name == null ? "" : name.toUpperCase(Locale.ROOT);
        for (Psd2Role role : values()) {
            if (role.roleName.equals(upper)) {
                return Optional.of(role);
            }
        }
        return Optional.empty();
    }
}
