package ch.obya.psd2.bank.xs2a;

import ch.obya.psd2.bank.consent.AccountAccess;
import ch.obya.psd2.bank.consent.AuthorisationId;
import ch.obya.psd2.bank.consent.ConsentId;
import ch.obya.psd2.bank.consent.ConsentRequest;
import ch.obya.psd2.bank.consent.ConsentRequestException;
import ch.obya.psd2.bank.consent.ConsentService;
import ch.obya.psd2.bank.gateway.QwacFilter;
import ch.obya.psd2.bank.gateway.TppMessages;
import ch.obya.psd2.bank.tpp.Psd2Role;
import ch.obya.psd2.bank.tpp.TppIdentity;
import jakarta.servlet.http.HttpServletRequest;
import java.net.URI;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * {@code /v1/consents} — NextGenPSD2 §6.3.
 *
 * <p>The controller lives in the application module for now rather than in
 * {@code bank-consent}, so the aggregates stay free of Spring and the ArchUnit rule that
 * says so keeps its teeth. It does no deciding: validation, capping and the
 * consent/authorisation pair all belong to {@link ConsentService}; this only renders.
 */
@RestController
@RequestMapping(GatewayConfiguration.XS2A_PREFIX + "/consents")
public class ConsentsController {

    private final ConsentService consents;
    private final String oidcMetadataUrl;

    public ConsentsController(ConsentService consents,
            @org.springframework.beans.factory.annotation.Value(
                    "${sandbox.oidc.metadata-url:https://oidc-provider.sandbox/"
                            + ".well-known/oauth-authorization-server}") String oidcMetadataUrl) {
        this.consents = consents;
        this.oidcMetadataUrl = oidcMetadataUrl;
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> create(
            @RequestBody CreateConsent body,
            @RequestHeader(value = "TPP-Redirect-URI", required = false) String redirectUri,
            @RequestHeader(value = "TPP-Nok-Redirect-URI", required = false) String nokRedirectUri,
            @RequestHeader(value = "PSU-ID", required = false) String psuId,
            HttpServletRequest request) {

        TppIdentity identity = identityOf(request);

        ConsentService.Created created = consents.create(new ConsentRequest(
                identity.organizationIdentifier(),
                body.toAccess(),
                Boolean.TRUE.equals(body.recurringIndicator()),
                body.validUntil(),
                body.frequencyPerDay() == null ? 1 : body.frequencyPerDay(),
                Boolean.TRUE.equals(body.combinedServiceIndicator()),
                redirectUri, nokRedirectUri, psuId));

        String consentId = created.consent().id().value();
        String authorisationId = created.authorisation().id().value();
        String self = GatewayConfiguration.XS2A_PREFIX + "/consents/" + consentId;

        Map<String, Object> links = new LinkedHashMap<>();
        links.put("self", href(self));
        links.put("status", href(self + "/status"));
        links.put("scaStatus", href(self + "/authorisations/" + authorisationId));
        links.put("scaOAuth", href(oidcMetadataUrl));
        if (created.confirmationRequired()) {
            links.put("confirmation", href(self + "/authorisations/" + authorisationId));
        }

        Map<String, Object> answer = new LinkedHashMap<>();
        answer.put("consentStatus", created.consent().status().wireName());
        answer.put("consentId", consentId);
        answer.put("_links", links);

        return ResponseEntity.created(URI.create(self))
                // §4.6: the approach is announced on every resource that starts an SCA.
                .header("ASPSP-SCA-Approach", created.consent().scaApproach().name())
                .body(answer);
    }

    @GetMapping("/{consentId}/status")
    public Map<String, Object> status(@PathVariable String consentId,
            HttpServletRequest request) {
        return Map.of("consentStatus",
                consents.require(new ConsentId(consentId), identityOf(request).organizationIdentifier())
                        .status().wireName());
    }

    @GetMapping("/{consentId}/authorisations")
    public Map<String, Object> authorisations(@PathVariable String consentId,
            HttpServletRequest request) {
        consents.require(new ConsentId(consentId), identityOf(request).organizationIdentifier());
        return Map.of("authorisationIds", consents.authorisationIdsOf(new ConsentId(consentId)));
    }

    @GetMapping("/{consentId}/authorisations/{authorisationId}")
    public Map<String, Object> scaStatus(@PathVariable String consentId,
            @PathVariable String authorisationId, HttpServletRequest request) {
        consents.require(new ConsentId(consentId), identityOf(request).organizationIdentifier());
        return Map.of("scaStatus", consents
                .requireAuthorisation(new ConsentId(consentId), new AuthorisationId(authorisationId))
                .scaStatus().wireName());
    }

    /**
     * Renders a refusal as §4.13 requires. {@code CONSENT_UNKNOWN} is 403 and everything
     * else here is 400, which is what the scenarios assert.
     */
    @ExceptionHandler(ConsentRequestException.class)
    public ResponseEntity<String> refused(ConsentRequestException refusal) {
        HttpStatus status = "CONSENT_UNKNOWN".equals(refusal.code())
                ? HttpStatus.FORBIDDEN : HttpStatus.BAD_REQUEST;
        // Rendered by TppMessages, not by the message converters, so that a refusal from
        // a controller and a refusal from the gateway filter are byte-identical. Jackson
        // would otherwise emit "path": null here and the filter would omit it.
        return ResponseEntity.status(status)
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .body(TppMessages.of(refusal.code(), refusal.getMessage(), refusal.path())
                        .toJson());
    }

    private static TppIdentity identityOf(HttpServletRequest request) {
        TppIdentity identity =
                (TppIdentity) request.getAttribute(QwacFilter.IDENTITY_ATTRIBUTE);
        if (identity == null) {
            throw new IllegalStateException("the QWAC filter did not run");
        }
        if (!identity.holds(Psd2Role.AISP)) {
            throw new ConsentRequestException("ROLE_INVALID", null,
                    "certificate does not hold AISP");
        }
        return identity;
    }

    private static Map<String, String> href(String value) {
        return Map.of("href", value);
    }

    /**
     * The request body of §14.17. Unknown fields are ignored, which is what
     * "an unknown field is ignored" asks for and what §4.16 data extensions require.
     */
    public record CreateConsent(
            Access access, Boolean recurringIndicator, LocalDate validUntil,
            Integer frequencyPerDay, Boolean combinedServiceIndicator) {

        AccountAccess toAccess() {
            return access == null ? null : new AccountAccess(
                    List.of(), List.of(), List.of(),
                    access.availableAccounts(), access.availableAccountsWithBalance(),
                    access.allPsd2());
        }

        /** Empty arrays mean bank-offered; the named variants arrive with increment 2. */
        public record Access(List<Object> accounts, List<Object> balances,
                List<Object> transactions, String availableAccounts,
                String availableAccountsWithBalance, String allPsd2) {
        }
    }
}
