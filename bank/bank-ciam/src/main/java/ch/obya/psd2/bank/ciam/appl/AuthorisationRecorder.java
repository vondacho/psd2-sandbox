package ch.obya.psd2.bank.ciam.appl;

import ch.obya.psd2.bank.ciam.domain.*;

import java.util.List;

/**
 * The outbound port to consent management: where an approved SCA is reported.
 *
 * <p>The context map makes consent management upstream of the CIAM (customer-supplier),
 * so the CIAM speaks the consent's language here — but over HTTP, never by importing the
 * consent model. The adapter behind this port is the only place that knows the Bank's
 * internal API exists.
 */
@FunctionalInterface
public interface AuthorisationRecorder {

    /**
     * @param consentId the subject the session authorised
     * @param authorisationId the sub-resource, learnt from the brokered request
     * @return what consent management made of it
     * @throws RecordingFailed when the Bank could not be reached or refused
     */
    Recorded record(String consentId, String authorisationId, String psuId,
            String challengeId, List<DynamicLink.SelectedAccount> accounts)
            throws RecordingFailed;

    /** What came back: the CIAM shows the PSU a different page for each. */
    record Recorded(String scaStatus, String consentStatus) {
    }

    /** The Bank did not accept the outcome. The PSU approved; the record did not stick. */
    class RecordingFailed extends Exception {
        public RecordingFailed(String message) {
            super(message);
        }
    }
}
