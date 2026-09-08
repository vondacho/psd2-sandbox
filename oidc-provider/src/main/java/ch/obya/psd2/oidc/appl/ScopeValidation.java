package ch.obya.psd2.oidc.appl;

import ch.obya.psd2.oidc.domain.*;

import java.util.Optional;
import java.util.function.BiConsumer;

/**
 * Decides whether an authorization request may proceed to brokered authentication.
 *
 * <p>This is the hook §13 says an off-the-shelf authorization server would need: "custom
 * scope validation hook". In Spring Authorization Server it becomes an
 * {@code AuthenticationProvider} in front of the authorization-code request; the decision
 * itself lives here so it is testable without a servlet.
 *
 * <p>The order of checks matters and is not arbitrary. The scope grammar is checked
 * before the client's roles, and the roles before the Bank is called, so that a malformed
 * request never costs an internal round trip and a client that could not hold the scope
 * anyway never learns whether the resource exists.
 */
public final class ScopeValidation {

    private final ConsentLookup consents;
    private final BiConsumer<String, String> refusalLog;

    public ScopeValidation(ConsentLookup consents) {
        this(consents, (clientId, message) -> { });
    }

    /**
     * @param refusalLog receives (clientId, message) on every refusal. "The refusal is
     *     logged with both client ids" when a TPP asks for someone else's resource, which
     *     is the only place the owner's id may appear — never in the response.
     */
    public ScopeValidation(ConsentLookup consents, BiConsumer<String, String> refusalLog) {
        this.consents = consents;
        this.refusalLog = refusalLog;
    }

    /**
     * @param client the registration resolved from the client id, absent when unknown
     * @param scope the raw {@code scope} parameter
     */
    public AuthorizationDecision validate(Optional<ClientRegistration> client, String scope) {
        if (client.isEmpty()) {
            return refuse(null, AuthorizationDecision.UNAUTHORIZED_CLIENT, "unknown client");
        }
        ClientRegistration registration = client.get();
        String clientId = registration.clientId().value();

        RequestedScope requested = RequestedScope.parse(scope);
        if (!requested.isAccepted()) {
            return refuse(clientId, AuthorizationDecision.INVALID_SCOPE,
                    requested.errorDescription().orElse("invalid scope"));
        }
        ScopeTarget target = requested.target();

        Optional<Psd2Role> required = target.kind().requiredRole();
        if (required.isPresent() && !registration.holds(required.get())) {
            return refuse(clientId, AuthorizationDecision.INVALID_SCOPE,
                    "the client does not hold " + required.get());
        }

        ResourceStatus status;
        try {
            status = consents.lookup(target.resourceId(), clientId);
        } catch (ConsentLookup.LookupUnavailable e) {
            // Not a refusal of the request: the Bank could not answer. RFC 6749 has a
            // code for exactly this, and the TPP is expected to retry.
            return refuse(clientId, AuthorizationDecision.TEMPORARILY_UNAVAILABLE,
                    "the Bank is temporarily unavailable");
        }

        if (!status.exists()) {
            return refuse(clientId, AuthorizationDecision.INVALID_SCOPE, "unknown resource");
        }
        if (!status.ownedByClient()) {
            // Logged with both ids; answered with the same words as "unknown resource"
            // would give, so ownership is not disclosed to the caller.
            refusalLog.accept(clientId,
                    "client " + clientId + " asked for resource " + target.resourceId()
                            + " it does not own");
            return new AuthorizationDecision(false, null, false,
                    AuthorizationDecision.INVALID_SCOPE, "unknown resource");
        }
        if (!status.isReceived()) {
            return refuse(clientId, AuthorizationDecision.INVALID_SCOPE,
                    "resource not in status received");
        }
        return AuthorizationDecision.proceed(target, requested.offlineAccess());
    }

    private AuthorizationDecision refuse(String clientId, String error, String description) {
        refusalLog.accept(clientId, error + ": " + description);
        return AuthorizationDecision.refuse(error, description);
    }
}
