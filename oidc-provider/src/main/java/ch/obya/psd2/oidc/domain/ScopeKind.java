package ch.obya.psd2.oidc.domain;

import java.util.Optional;

/**
 * The scope kinds of §13.1. Each names exactly one resource, except
 * {@code offline_access}, which names none and only asks for a refresh token.
 */
public enum ScopeKind {
    AIS("AIS", Psd2Role.AISP),
    PIS("PIS", Psd2Role.PISP),
    PIIS("PIIS", Psd2Role.PIISP),
    CANCEL_PIS("Cancel-PIS", Psd2Role.PISP),
    OFFLINE_ACCESS("offline_access", null);

    private final String prefix;
    private final Psd2Role requiredRole;

    ScopeKind(String prefix, Psd2Role requiredRole) {
        this.prefix = prefix;
        this.requiredRole = requiredRole;
    }

    public String prefix() {
        return prefix;
    }

    /** "the scope kind decides the role": AIS needs AISP, PIS and Cancel-PIS need PISP. */
    public Optional<Psd2Role> requiredRole() {
        return Optional.ofNullable(requiredRole);
    }

    /** True when this kind names a resource, i.e. everything but {@code offline_access}. */
    public boolean namesAResource() {
        return this != OFFLINE_ACCESS;
    }

    static Optional<ScopeKind> byPrefix(String prefix) {
        for (ScopeKind kind : values()) {
            if (kind.prefix.equals(prefix)) {
                return Optional.of(kind);
            }
        }
        return Optional.empty();
    }
}
