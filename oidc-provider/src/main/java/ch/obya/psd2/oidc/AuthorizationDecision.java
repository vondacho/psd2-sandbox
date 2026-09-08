package ch.obya.psd2.oidc;

/**
 * What the authorization endpoint does with a request: proceed to broker the PSU to the
 * Bank, or redirect to the TPP with an OAuth2 error and the state.
 *
 * <p>A refusal is a value because RFC 6749 says it travels back through the browser as a
 * redirect, not as an error page: "the OIDC-provider redirects to the TPP with
 * error=invalid_scope and the state".
 */
public record AuthorizationDecision(
        boolean proceed, ScopeTarget target, boolean offlineAccess,
        String error, String errorDescription) {

    /** RFC 6749 §4.1.2.1. */
    public static final String INVALID_SCOPE = "invalid_scope";
    public static final String INVALID_REQUEST = "invalid_request";
    public static final String UNAUTHORIZED_CLIENT = "unauthorized_client";
    public static final String TEMPORARILY_UNAVAILABLE = "temporarily_unavailable";

    public static AuthorizationDecision proceed(ScopeTarget target, boolean offlineAccess) {
        return new AuthorizationDecision(true, target, offlineAccess, null, null);
    }

    public static AuthorizationDecision refuse(String error, String description) {
        return new AuthorizationDecision(false, null, false, error, description);
    }

    /** True when the endpoint must redirect to the TPP with {@link #error()}. */
    public boolean isRefusal() {
        return !proceed;
    }
}
