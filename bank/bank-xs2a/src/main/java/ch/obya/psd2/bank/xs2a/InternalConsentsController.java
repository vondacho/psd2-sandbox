package ch.obya.psd2.bank.xs2a;

import ch.obya.psd2.bank.consent.Consent;
import ch.obya.psd2.bank.consent.ConsentId;
import ch.obya.psd2.bank.consent.ConsentService;
import java.util.Optional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
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

    /** Three fields. Widening this is a breach of the layer, not a convenience. */
    public record ResourceStatus(boolean exists, boolean ownedByClient, String status) {
    }
}
