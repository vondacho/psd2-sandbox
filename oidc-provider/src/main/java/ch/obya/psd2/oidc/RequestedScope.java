package ch.obya.psd2.oidc;

import java.util.Optional;

/**
 * The parsed {@code scope} parameter of an authorization request.
 *
 * <p>§13.1 allows exactly one resource scope, optionally with {@code offline_access}.
 * Anything else — two resources, a mix of kinds, no resource at all, an unknown word —
 * is {@code invalid_scope}. Parsing therefore returns a result rather than throwing,
 * because the answer is a redirect to the TPP carrying the error and the state, not an
 * exception page.
 */
public record RequestedScope(ScopeTarget target, boolean offlineAccess, String error) {

    public static RequestedScope accepted(ScopeTarget target, boolean offlineAccess) {
        return new RequestedScope(target, offlineAccess, null);
    }

    public static RequestedScope rejected(String description) {
        return new RequestedScope(null, false, description);
    }

    public boolean isAccepted() {
        return error == null;
    }

    public Optional<String> errorDescription() {
        return Optional.ofNullable(error);
    }

    /**
     * Parses a space-delimited scope string.
     *
     * <pre>
     *   AIS:123cons456 offline_access   accepted
     *   AIS:123cons456                  accepted
     *   AIS:123cons456 AIS:111cons222   invalid_scope, two resources
     *   AIS:123cons456 PIS:pay001       invalid_scope, two resources
     *   offline_access                  invalid_scope, no resource
     *   AIS:123cons456 admin            invalid_scope, unknown word
     *   AIS:                            invalid_scope, empty id
     * </pre>
     */
    public static RequestedScope parse(String scope) {
        if (scope == null || scope.isBlank()) {
            return rejected("no resource named");
        }
        ScopeTarget target = null;
        boolean offlineAccess = false;

        for (String word : scope.trim().split("\\s+")) {
            if (ScopeKind.OFFLINE_ACCESS.prefix().equals(word)) {
                offlineAccess = true;
                continue;
            }
            int colon = word.indexOf(':');
            if (colon < 0) {
                return rejected("unknown scope " + word);
            }
            Optional<ScopeKind> kind = ScopeKind.byPrefix(word.substring(0, colon));
            if (kind.isEmpty() || !kind.get().namesAResource()) {
                return rejected("unknown scope " + word);
            }
            String resourceId = word.substring(colon + 1);
            if (resourceId.isBlank()) {
                return rejected("scope names no resource");
            }
            if (target != null) {
                return rejected("the scope names more than one resource");
            }
            target = new ScopeTarget(kind.get(), resourceId);
        }
        if (target == null) {
            return rejected("the scope names no resource");
        }
        return accepted(target, offlineAccess);
    }
}
