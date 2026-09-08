package ch.obya.psd2.bank.consent.appl;

import ch.obya.psd2.bank.consent.domain.*;

import ch.obya.psd2.spec.OrganizationIdentifier;
import java.time.LocalDate;

/**
 * What the TPP sent on {@code POST /v1/consents}: the body, plus the headers and the
 * certificate identity the gateway already resolved.
 *
 * @param access the {@code access} object; null is refused
 * @param validUntil {@code 9999-12-31} means "the maximum the Bank allows"
 * @param psuId from the optional {@code PSU-ID} header, before any login
 */
public record ConsentRequest(
        OrganizationIdentifier tppId,
        AccountAccess access,
        boolean recurringIndicator,
        LocalDate validUntil,
        int frequencyPerDay,
        boolean combinedServiceIndicator,
        String tppRedirectUri,
        String tppNokRedirectUri,
        String psuId) {

    /** The sentinel §14.17 gives for "as long as the Bank allows". */
    public static final LocalDate MAXIMUM = LocalDate.of(9999, 12, 31);
}
