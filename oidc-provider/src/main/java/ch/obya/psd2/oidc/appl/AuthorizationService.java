package ch.obya.psd2.oidc.appl;

import ch.obya.psd2.oidc.domain.*;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * The authorization-code flow: validate the request, hold it while the PSU authenticates
 * at the Bank, issue a code, and redeem it once.
 *
 * <p>Scope validation is {@link ScopeValidation}'s and stays there; this is the state
 * around it.
 */
public final class AuthorizationService {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final Clock clock;
    private final ScopeValidation scopes;
    private final Map<String, PendingRequest> pending = new ConcurrentHashMap<>();
    private final Map<String, AuthorizationCode> codes = new ConcurrentHashMap<>();
    private final Map<String, ClientRegistration> clients = new ConcurrentHashMap<>();

    public AuthorizationService(Clock clock, ScopeValidation scopes) {
        this.clock = clock;
        this.scopes = scopes;
    }

    public void register(ClientRegistration client) {
        clients.put(client.clientId().value(), client);
    }

    public Optional<ClientRegistration> client(String clientId) {
        return Optional.ofNullable(clients.get(clientId));
    }

    /**
     * Starts an authorization request.
     *
     * <p>The redirect URI is checked before anything else, because a request whose
     * redirect URI is not registered must <em>not</em> be answered with a redirect —
     * there is nowhere safe to send the error.
     */
    public Started start(String clientId, String redirectUri, String scope, String state,
            String codeChallenge) {
        Optional<ClientRegistration> client = client(clientId);
        if (client.isEmpty() || !client.get().allowsRedirectTo(redirectUri)) {
            return Started.refusedWithoutRedirect("unknown client or redirect URI");
        }
        AuthorizationDecision decision = scopes.validate(client, scope);
        if (!decision.proceed()) {
            return Started.refused(decision.error(), decision.errorDescription());
        }
        String requestId = randomToken();
        pending.put(requestId, new PendingRequest(clientId, redirectUri, state,
                codeChallenge, decision.target(), decision.offlineAccess()));
        return Started.brokering(requestId, decision.target());
    }

    public Optional<PendingRequest> pending(String requestId) {
        return Optional.ofNullable(pending.get(requestId));
    }

    /**
     * The Bank has authenticated the PSU and approved the consent. Issues the code.
     *
     * <p>"One request yields at most one code": the pending request is consumed here, so
     * a second callback for the same request finds nothing.
     */
    public Optional<AuthorizationCode> issueCode(String requestId, String psuSubject,
            String acr, List<String> amr) {
        PendingRequest request = pending.remove(requestId);
        if (request == null) {
            return Optional.empty();
        }
        AuthorizationCode code = new AuthorizationCode(randomToken(), request.clientId(),
                request.redirectUri(), request.codeChallenge(), request.target(),
                request.offlineAccess(), psuSubject, acr, amr, clock.instant());
        codes.put(code.code(), code);
        return Optional.of(code);
    }

    /** Redeems a code at the token endpoint. */
    public Redeemed redeem(String code, String clientId, String redirectUri,
            String codeVerifier) {
        AuthorizationCode authorizationCode = codes.get(code);
        if (authorizationCode == null) {
            return new Redeemed(null, AuthorizationCode.Redemption.ALREADY_REDEEMED);
        }
        Instant now = clock.instant();
        AuthorizationCode.Redemption outcome =
                authorizationCode.redeem(clientId, redirectUri, codeVerifier, now);
        return new Redeemed(outcome.isOk() ? authorizationCode : null, outcome);
    }

    private static String randomToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    /** An authorization request waiting for the Bank to authenticate the PSU. */
    public record PendingRequest(String clientId, String redirectUri, String state,
            String codeChallenge, ScopeTarget target, boolean offlineAccess) {
    }

    /**
     * What {@code /authorize} should do next.
     *
     * @param redirectSafe false when the redirect URI itself was not acceptable, in
     *     which case the error must be shown, not redirected
     */
    public record Started(String requestId, ScopeTarget target, String error,
            String errorDescription, boolean redirectSafe) {

        static Started brokering(String requestId, ScopeTarget target) {
            return new Started(requestId, target, null, null, true);
        }

        static Started refused(String error, String description) {
            return new Started(null, null, error, description, true);
        }

        static Started refusedWithoutRedirect(String description) {
            return new Started(null, null, AuthorizationDecision.INVALID_REQUEST,
                    description, false);
        }

        public boolean proceed() {
            return error == null;
        }
    }

    public record Redeemed(AuthorizationCode code, AuthorizationCode.Redemption outcome) {
    }
}
