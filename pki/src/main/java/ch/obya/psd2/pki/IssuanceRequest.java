package ch.obya.psd2.pki;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Set;

/**
 * One certificate to issue.
 *
 * @param alias short name used for the output files, e.g. {@code tpp}
 * @param kind QWAC or QSEAL
 * @param roles the PSD2 roles; never empty
 * @param organizationName the {@code O} of the subject, e.g. {@code TPP Fintech GmbH}
 * @param organizationIdentifier the {@code organizationIdentifier} (OID 2.5.4.97), which
 *     is also the {@code client_id} everywhere else in the sandbox
 * @param ncaName competent authority name, e.g. {@code BaFin}
 * @param ncaId competent authority id, e.g. {@code DE-BAFIN}
 * @param dnsNames subjectAltName dNSName entries. §4.10 requires a TPP's redirect URIs to
 *     lie in this domain, so the hostname plan and the certificate plan are one plan.
 * @param notBefore validity start
 * @param validity validity length; the sandbox default is 365 days
 */
public record IssuanceRequest(
        String alias,
        CertificateKind kind,
        Set<Psd2Role> roles,
        String organizationName,
        String organizationIdentifier,
        String ncaName,
        String ncaId,
        List<String> dnsNames,
        Instant notBefore,
        Duration validity) {

    /** The sandbox default when a request states no validity. */
    public static final Duration DEFAULT_VALIDITY = Duration.ofDays(365);

    public IssuanceRequest {
        if (roles.isEmpty()) {
            throw new IllegalArgumentException("at least one PSD2 role is required");
        }
        roles = Set.copyOf(roles);
        dnsNames = List.copyOf(dnsNames);
    }

    public Instant notAfter() {
        return notBefore.plus(validity);
    }
}
