package ch.obya.psd2.authorisation;

import java.util.Set;

/**
 * The SCA status of an authorisation sub-resource, NextGenPSD2 §7.
 *
 * <p>The nine values are those of {@code consent-management.ddm}. Payment initiation
 * deliberately declares {@code enum "ScaStatus" { }} empty in its own model and defers
 * to this one, which is what the shared-kernel relationship in the context map means.
 *
 * <p>The terminal set is <em>not</em> a property of this enum. Consent management treats
 * {@code finalised}, {@code failed} and {@code exempted} as terminal; payment initiation
 * treats only {@code finalised} and {@code failed} as terminal. Each context supplies its
 * own set to {@link Transitions}.
 */
public enum ScaStatus {
    RECEIVED("received"),
    PSU_IDENTIFIED("psuIdentified"),
    PSU_AUTHENTICATED("psuAuthenticated"),
    SCA_METHOD_SELECTED("scaMethodSelected"),
    STARTED("started"),
    UNCONFIRMED("unconfirmed"),
    FINALISED("finalised"),
    FAILED("failed"),
    EXEMPTED("exempted");

    private final String wireName;

    ScaStatus(String wireName) {
        this.wireName = wireName;
    }

    /** The value as it appears on the XS2A interface. */
    public String wireName() {
        return wireName;
    }

    public static ScaStatus ofWireName(String wireName) {
        for (ScaStatus s : values()) {
            if (s.wireName.equals(wireName)) {
                return s;
            }
        }
        throw new IllegalArgumentException("not an scaStatus: " + wireName);
    }

    /** Terminal set of consent management: {@code finalised}, {@code failed}, {@code exempted}. */
    public static Set<ScaStatus> consentTerminals() {
        return Set.of(FINALISED, FAILED, EXEMPTED);
    }

    /** Terminal set of payment initiation: {@code finalised}, {@code failed}. */
    public static Set<ScaStatus> paymentTerminals() {
        return Set.of(FINALISED, FAILED);
    }
}
