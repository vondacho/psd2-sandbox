package ch.obya.psd2.bank.xs2a.adapter.in;

import ch.obya.psd2.bank.accounts.appl.AccountInformation;
import ch.obya.psd2.bank.accounts.domain.AccountResource;
import ch.obya.psd2.bank.accounts.domain.Balance;
import ch.obya.psd2.bank.consent.appl.ConsentService;
import ch.obya.psd2.bank.consent.domain.Consent;
import ch.obya.psd2.bank.consent.domain.ConsentId;
import ch.obya.psd2.bank.consent.domain.ConsentRequestException;
import ch.obya.psd2.bank.gateway.adapter.in.QwacFilter;
import ch.obya.psd2.bank.gateway.adapter.in.TppMessages;
import ch.obya.psd2.bank.tpp.domain.Psd2Role;
import ch.obya.psd2.bank.tpp.domain.TppIdentity;
import ch.obya.psd2.bank.xs2a.config.GatewayConfiguration;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * {@code /v1/accounts} — NextGenPSD2 §6.5.
 *
 * <p>Paths take a {@code resourceId} and never an IBAN: "paths never accept an IBAN, PAN
 * or BBAN". A resource id is a handle into one consent, so a URL that leaks tells an
 * attacker nothing and works for nobody else.
 */
@RestController
@RequestMapping(GatewayConfiguration.XS2A_PREFIX + "/accounts")
public class AccountsController {

    private final ConsentService consents;
    private final AccountInformation accounts;
    private final Clock clock;

    public AccountsController(ConsentService consents, AccountInformation accounts,
            Clock clock) {
        this.consents = consents;
        this.accounts = accounts;
        this.clock = clock;
    }

    @GetMapping
    public Map<String, Object> list(
            @RequestHeader(value = "Consent-ID", required = false) String consentId,
            @RequestParam(value = "withBalance", defaultValue = "false") boolean withBalance,
            HttpServletRequest request) {

        Consent consent = servingConsent(consentId, request);
        return Map.of("accounts", accounts.list(consent, withBalance).stream()
                .map(account -> render(account, consent))
                .toList());
    }

    @GetMapping("/{resourceId}")
    public Map<String, Object> one(@PathVariable String resourceId,
            @RequestHeader(value = "Consent-ID", required = false) String consentId,
            @RequestParam(value = "withBalance", defaultValue = "false") boolean withBalance,
            HttpServletRequest request) {

        Consent consent = servingConsent(consentId, request);
        return accounts.byResourceId(consent, resourceId, withBalance)
                .<Map<String, Object>>map(account -> Map.of("account", render(account, consent)))
                // Not 404: the resource id is unknown *to this consent*, which is a
                // consent question, and answering differently would confirm it exists.
                .orElseThrow(() -> new ConsentRequestException("RESOURCE_UNKNOWN", null,
                        "no account " + resourceId + " under this consent"));
    }

    /**
     * The consent this call may serve from.
     *
     * @throws ConsentRequestException when the header is missing, names a consent of
     *     another TPP, or names one that is not valid
     */
    private Consent servingConsent(String consentId, HttpServletRequest request) {
        TppIdentity identity = (TppIdentity) request.getAttribute(QwacFilter.IDENTITY_ATTRIBUTE);
        if (identity == null || !identity.holds(Psd2Role.AISP)) {
            throw new ConsentRequestException("ROLE_INVALID", null,
                    "certificate does not hold AISP");
        }
        if (consentId == null || consentId.isBlank()) {
            throw ConsentRequestException.formatError("Consent-ID", "Consent-ID is mandatory");
        }
        Consent consent = consents.require(new ConsentId(consentId),
                identity.organizationIdentifier());

        if (!accounts.mayServe(consent, LocalDate.ofInstant(clock.instant(), ZoneOffset.UTC))) {
            throw new ConsentRequestException("CONSENT_INVALID", null,
                    "the consent is " + consent.status().wireName());
        }
        return consent;
    }

    private Map<String, Object> render(AccountResource account, Consent consent) {
        String self = GatewayConfiguration.XS2A_PREFIX + "/accounts/" + account.resourceId();
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("resourceId", account.resourceId());
        body.put("iban", account.iban());
        body.put("currency", account.currency());
        if (account.name() != null) {
            body.put("name", account.name());
        }
        if (account.product() != null) {
            body.put("product", account.product());
        }
        if (account.ownerName() != null) {
            body.put("ownerName", account.ownerName());
        }
        if (!account.balances().isEmpty()) {
            body.put("balances", account.balances().stream().map(this::render).toList());
        }
        Map<String, Object> links = new LinkedHashMap<>();
        links.put("self", Map.of("href", self));
        links.put("balances", Map.of("href", self + "/balances"));
        links.put("transactions", Map.of("href", self + "/transactions"));
        body.put("_links", links);
        return body;
    }

    private Map<String, Object> render(Balance balance) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("balanceType", balance.type().wireName());
        body.put("balanceAmount", Map.of(
                "currency", balance.currency(), "amount", balance.amount().toPlainString()));
        if (balance.lastChangeDateTime() != null) {
            body.put("lastChangeDateTime", balance.lastChangeDateTime().toString());
        }
        return body;
    }

    @ExceptionHandler(ConsentRequestException.class)
    public ResponseEntity<String> refused(ConsentRequestException refusal) {
        HttpStatus status = switch (refusal.code()) {
            case "CONSENT_UNKNOWN", "RESOURCE_UNKNOWN", "CONSENT_INVALID" -> HttpStatus.FORBIDDEN;
            case "ROLE_INVALID" -> HttpStatus.UNAUTHORIZED;
            default -> HttpStatus.BAD_REQUEST;
        };
        return ResponseEntity.status(status).contentType(MediaType.APPLICATION_JSON)
                .body(TppMessages.of(refusal.code(), refusal.getMessage(), refusal.path())
                        .toJson());
    }
}
