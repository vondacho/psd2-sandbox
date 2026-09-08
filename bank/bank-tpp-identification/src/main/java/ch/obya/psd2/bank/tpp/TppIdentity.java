package ch.obya.psd2.bank.tpp;

import ch.obya.psd2.spec.OrganizationIdentifier;
import java.time.Instant;
import java.util.Optional;
import java.util.Set;

/**
 * Who is calling, derived from the certificate presented on this connection and from
 * nothing else.
 *
 * <p>"Nothing here is remembered about a TPP beyond what its certificate says", and
 * "no field is inferred from an earlier call" — {@code tpp-identification.ddm}. The type
 * therefore carries a refusal as a value rather than throwing: the gateway, the payment
 * endpoints and the OIDC-provider all need the same answer, refusals included.
 */
public record TppIdentity(
        OrganizationIdentifier organizationIdentifier,
        String legalName,
        CertificateKind kind,
        CertificateChainDetails chain,
        QcStatementDetails qcStatement,
        CertificateVerdict verdict,
        String reason,
        Instant identifiedAt) {

    /** True when the certificate was accepted and an identity exists. */
    public boolean isIdentified() {
        return verdict == CertificateVerdict.VALID;
    }

    public Set<Psd2Role> roles() {
        return qcStatement == null ? Set.of() : qcStatement.roles();
    }

    /**
     * "An endpoint is served only when the identity holds the role that endpoint
     * requires."
     */
    public boolean holds(Psd2Role required) {
        return isIdentified() && roles().contains(required);
    }

    /** The {@code tppMessages} code to answer with, empty when the identity is valid. */
    public Optional<String> messageCode() {
        return Optional.ofNullable(verdict.messageCode());
    }

    /** A refusal carrying no identity, for a certificate that could not be read. */
    static TppIdentity refusal(CertificateVerdict verdict, String reason,
            CertificateChainDetails chain, Instant at) {
        return new TppIdentity(null, null, null, chain, null, verdict, reason, at);
    }
}
