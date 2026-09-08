package ch.obya.psd2.bank.tpp;

import ch.obya.psd2.spec.OrganizationIdentifier;
import java.util.Set;

/**
 * The PSD2 qualified statement read out of the certificate.
 *
 * <p>"A certificate without a PSD2 qualified statement yields no identity" —
 * {@code tpp-identification.ddm}.
 */
public record QcStatementDetails(
        OrganizationIdentifier organizationIdentifier,
        String ncaName,
        String ncaId,
        Set<Psd2Role> roles) {

    public QcStatementDetails {
        roles = Set.copyOf(roles);
    }
}
