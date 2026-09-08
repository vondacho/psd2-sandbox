package ch.obya.psd2.bank.xs2a;

import ch.obya.psd2.bank.consent.AccessType;
import ch.obya.psd2.bank.consent.AccountReference;
import ch.obya.psd2.bank.consent.AuthorisationId;
import ch.obya.psd2.bank.consent.AuthorisationOutcome;
import ch.obya.psd2.bank.consent.Consent;
import ch.obya.psd2.bank.consent.ConsentId;
import ch.obya.psd2.bank.consent.ConsentService;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * The Bank's half of the anticorruption layer to the OIDC-provider (§7.7).
 *
 * <p>{@code GET /internal/consents/{id}?client_id=} answers three fields and no more.
 * "The OIDC-provider must never learn the consent model beyond existence and status",
 * so there is deliberately no {@code access}, no {@code psuId}, no {@code validUntil}
 * and no {@code accounts} in the response — the OIDC-provider's own
 * {@code ResourceStatus} record has a test asserting the same arity from its side.
 *
 * <p>Not TPP-facing, so it carries no QWAC and the gateway filter skips it.
 */
@RestController
public class InternalConsentsController {

    private static final Logger log = LoggerFactory.getLogger(InternalConsentsController.class);

    private final ConsentService consents;

    public InternalConsentsController(ConsentService consents) {
        this.consents = consents;
    }

    @GetMapping("/internal/consents/{consentId}")
    public ResourceStatus status(@PathVariable String consentId,
            @RequestParam("client_id") String clientId) {
        Optional<Consent> consent = consents.find(new ConsentId(consentId));
        if (consent.isEmpty()) {
            return new ResourceStatus(false, false, null);
        }
        Consent found = consent.get();
        return new ResourceStatus(true,
                found.tppId().value().equalsIgnoreCase(clientId),
                found.status().wireName());
    }

    /**
     * The CIAM reports an approved authorisation (§7.7).
     *
     * <p>The other direction of the same internal API, but a different edge: this one is
     * customer-supplier, not an anticorruption layer, so the CIAM does speak the
     * consent's language here. It still is not the authority on what was requested —
     * access types it claims beyond the consent's request are trimmed, and the trim is
     * logged rather than silently dropped.
     */
    @PostMapping("/internal/consents/{consentId}/authorisations/{authorisationId}")
    public RecordedOutcome record(@PathVariable String consentId,
            @PathVariable String authorisationId, @RequestBody Outcome outcome) {

        ConsentService.Recorded recorded = consents.recordOutcome(
                new ConsentId(consentId), new AuthorisationId(authorisationId),
                new AuthorisationOutcome(outcome.psuId(), outcome.challengeId(),
                        outcome.accounts().stream()
                                .map(Outcome.Account::toChosen)
                                .toList()));

        if (!recorded.trimmedAccessTypes().isEmpty()) {
            log.warn("consent {}: the CIAM claimed access the consent did not request, "
                    + "trimmed {}", consentId, recorded.trimmedAccessTypes());
        }
        return new RecordedOutcome(
                recorded.authorisation().scaStatus().wireName(),
                recorded.consent().status().wireName(),
                recorded.consent().accessibleAccounts().size(),
                recorded.trimmedAccessTypes());
    }

    /** Three fields. Widening this is a breach of the layer, not a convenience. */
    public record ResourceStatus(boolean exists, boolean ownedByClient, String status) {
    }

    /** What the CIAM posts. */
    public record Outcome(String psuId, String challengeId, List<Account> accounts) {

        public record Account(String iban, String currency, List<String> accessTypes) {
            AuthorisationOutcome.ChosenAccount toChosen() {
                Set<AccessType> types = accessTypes.stream()
                        .map(name -> AccessType.valueOf(name.toUpperCase(Locale.ROOT)))
                        .collect(Collectors.toSet());
                return new AuthorisationOutcome.ChosenAccount(
                        AccountReference.ofIban(iban, currency), currency, types);
            }
        }
    }

    /** What the CIAM learns back: enough to steer its own screens, and nothing more. */
    public record RecordedOutcome(String scaStatus, String consentStatus,
            int accessibleAccounts, List<String> trimmed) {
    }
}
