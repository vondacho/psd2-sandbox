package ch.obya.psd2.oidc;

/**
 * One scope entry: a kind and the resource it names, e.g. {@code AIS:123cons456}.
 *
 * <p>{@code resourceId} is a {@code String}, deliberately. Both edges from the Bank to
 * token issuance are anticorruption layers: "the OIDC-provider must never learn the
 * consent model beyond existence and status. A thin layer keeps AIS:&lt;consentId&gt; an
 * opaque handle." Giving it a strong {@code ConsentId} type would breach that.
 */
public record ScopeTarget(ScopeKind kind, String resourceId) {

    public ScopeTarget {
        if (kind.namesAResource() && (resourceId == null || resourceId.isBlank())) {
            throw new IllegalArgumentException(kind.prefix() + " names no resource");
        }
    }

    @Override
    public String toString() {
        return kind.namesAResource() ? kind.prefix() + ":" + resourceId : kind.prefix();
    }
}
