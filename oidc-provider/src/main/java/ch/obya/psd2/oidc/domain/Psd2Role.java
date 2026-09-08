package ch.obya.psd2.oidc.domain;

/**
 * The roles a client can hold, read from its QWAC.
 *
 * <p>Three, matching {@code token-issuance.ddm}: {@code ASPSP} never appears as an
 * OAuth2 client role. The type is declared here rather than imported from TPP
 * identification because that edge is an open host service, not a shared kernel — this
 * context accepts the roles as data over the wire, it does not link the other's model.
 */
public enum Psd2Role {
    AISP, PISP, PIISP
}
