package ch.obya.psd2.oidc.domain;

import java.time.Duration;
import java.time.Instant;

/**
 * A single-use authorization code, bound to everything that must match at redemption.
 *
 * <p>"The code lives 60 seconds and is redeemable once." Both are enforced by
 * {@link #redeem}, not by the caller, because a code redeemed twice is an attacker
 * replaying one and a caller that forgets the check is the vulnerability.
 */
public final class AuthorizationCode {

    /** §13: an authorization code is short-lived. */
    public static final Duration LIFETIME = Duration.ofSeconds(60);

    private final String code;
    private final String clientId;
    private final String redirectUri;
    private final String codeChallenge;
    private final ScopeTarget target;
    private final boolean offlineAccess;
    private final String subject;
    private final String acr;
    private final java.util.List<String> amr;
    private final Instant issuedAt;

    private boolean redeemed;

    public AuthorizationCode(String code, String clientId, String redirectUri,
            String codeChallenge, ScopeTarget target, boolean offlineAccess,
            String subject, String acr, java.util.List<String> amr, Instant issuedAt) {
        this.code = code;
        this.clientId = clientId;
        this.redirectUri = redirectUri;
        this.codeChallenge = codeChallenge;
        this.target = target;
        this.offlineAccess = offlineAccess;
        this.subject = subject;
        this.acr = acr;
        this.amr = java.util.List.copyOf(amr);
        this.issuedAt = issuedAt;
    }

    public String code() {
        return code;
    }

    public ScopeTarget target() {
        return target;
    }

    public boolean offlineAccess() {
        return offlineAccess;
    }

    public String subject() {
        return subject;
    }

    public String acr() {
        return acr;
    }

    public java.util.List<String> amr() {
        return amr;
    }

    public String clientId() {
        return clientId;
    }

    /**
     * Redeems the code, checking everything RFC 6749 §4.1.3 and RFC 7636 require.
     *
     * @return why it was refused, or {@link Redemption#OK}
     */
    public Redemption redeem(String presentingClientId, String presentedRedirectUri,
            String codeVerifier, Instant now) {
        if (redeemed) {
            return Redemption.ALREADY_REDEEMED;
        }
        if (now.isAfter(issuedAt.plus(LIFETIME))) {
            return Redemption.EXPIRED;
        }
        if (!clientId.equals(presentingClientId)) {
            return Redemption.WRONG_CLIENT;
        }
        if (!redirectUri.equals(presentedRedirectUri)) {
            return Redemption.WRONG_REDIRECT_URI;
        }
        if (!Pkce.verifies(codeChallenge, codeVerifier)) {
            return Redemption.BAD_VERIFIER;
        }
        redeemed = true;
        return Redemption.OK;
    }

    public enum Redemption {
        OK, ALREADY_REDEEMED, EXPIRED, WRONG_CLIENT, WRONG_REDIRECT_URI, BAD_VERIFIER;

        public boolean isOk() {
            return this == OK;
        }
    }
}
