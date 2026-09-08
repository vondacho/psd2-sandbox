package ch.obya.psd2.bank.consent;

import java.util.List;
import java.util.Set;

/**
 * What the CIAM reports back after a PSU approved a challenge.
 *
 * <p>This is the payload of {@code POST /internal/consents/{id}/authorisations/{authId}},
 * the customer-supplier edge: "the CIAM speaks the consent's language when it shows and
 * updates it". It carries the outcome only — never a credential, never a signature.
 *
 * @param psuId who authorised; learnt at login, so the consent may not have known it
 * @param challengeId the approved challenge, kept as evidence for a later audit
 * @param accounts what the PSU ticked, with the access types the CIAM believes apply
 */
public record AuthorisationOutcome(
        String psuId, String challengeId, List<ChosenAccount> accounts) {

    public AuthorisationOutcome {
        accounts = List.copyOf(accounts);
    }

    /**
     * One account the PSU chose.
     *
     * @param accessTypes what the CIAM proposes; trimmed to the consent's request on
     *     recording, because the consent is the authority on what was asked for
     */
    public record ChosenAccount(AccountReference account, String currency,
            Set<AccessType> accessTypes) {
        public ChosenAccount {
            accessTypes = Set.copyOf(accessTypes);
        }
    }
}
