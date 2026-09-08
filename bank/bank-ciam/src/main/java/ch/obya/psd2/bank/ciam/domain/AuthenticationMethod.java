package ch.obya.psd2.bank.ciam.domain;

/**
 * What the PSU actually used, reported to the OIDC-provider as {@code amr}.
 *
 * <p>{@code pwd} is knowledge and {@code hwk} is possession — a hardware-backed key —
 * so a compliant SCA carries at least one of each.
 */
public enum AuthenticationMethod {
    PWD("pwd", true, false),
    HWK("hwk", false, true),
    OTP("otp", false, true),
    PIN("pin", true, false),
    FACE("face", false, false),
    FPT("fpt", false, false);

    private final String claim;
    private final boolean knowledge;
    private final boolean possession;

    AuthenticationMethod(String claim, boolean knowledge, boolean possession) {
        this.claim = claim;
        this.knowledge = knowledge;
        this.possession = possession;
    }

    /** The value as it appears in the ID token's {@code amr} array. */
    public String claim() {
        return claim;
    }

    public boolean isKnowledge() {
        return knowledge;
    }

    public boolean isPossession() {
        return possession;
    }
}
