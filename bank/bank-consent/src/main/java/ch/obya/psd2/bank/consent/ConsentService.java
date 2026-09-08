package ch.obya.psd2.bank.consent;

import ch.obya.psd2.spec.OrganizationIdentifier;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Supplier;

/**
 * Creates consents and their authorisation sub-resources, and answers the questions the
 * XS2A endpoints and the internal API ask about them.
 *
 * <p>Storage is in memory. The sandbox has no persistence requirement of its own and the
 * walking skeleton has no database, so the map is the repository; swapping it for JPA is
 * a change behind this class.
 */
public final class ConsentService {

    private final Clock clock;
    private final Supplier<String> consentIds;
    private final Supplier<String> authorisationIds;
    private final Map<String, Consent> consents = new ConcurrentHashMap<>();
    private final Map<String, Authorisation> authorisations = new ConcurrentHashMap<>();

    private volatile SandboxLimits limits;

    public ConsentService(Clock clock, SandboxLimits limits,
            Supplier<String> consentIds, Supplier<String> authorisationIds) {
        this.clock = clock;
        this.limits = limits;
        this.consentIds = consentIds;
        this.authorisationIds = authorisationIds;
    }

    public SandboxLimits limits() {
        return limits;
    }

    /** Swapped at run time by the sandbox admin endpoint. */
    public void applyLimits(SandboxLimits updated) {
        this.limits = updated;
    }

    /**
     * Creates a consent in {@code received} together with its implicit authorisation, as
     * §6.3.1.1 and §4.6 require.
     *
     * @throws ConsentRequestException when the body is not acceptable
     */
    public Created create(ConsentRequest request) {
        Instant now = clock.instant();
        LocalDate today = LocalDate.ofInstant(now, ZoneOffset.UTC);

        LocalDate validUntil = validate(request, today);
        int frequency = frequencyOf(request);

        Consent consent = new Consent(
                new ConsentId(consentIds.get()),
                request.tppId(),
                request.access(),
                request.recurringIndicator(),
                validUntil,
                frequency,
                request.combinedServiceIndicator(),
                request.tppRedirectUri(),
                request.tppNokRedirectUri(),
                ScaApproach.REDIRECT,
                request.psuId(),
                now);

        // §4.6: the authorisation sub-resource is created implicitly with the consent.
        Authorisation authorisation = new Authorisation(
                new AuthorisationId(authorisationIds.get()), consent.id(), now,
                limits.confirmationRequired());

        consents.put(consent.id().value(), consent);
        authorisations.put(authorisation.id().value(), authorisation);
        return new Created(consent, authorisation, limits.confirmationRequired());
    }

    private LocalDate validate(ConsentRequest request, LocalDate today) {
        if (request.access() == null) {
            throw ConsentRequestException.formatError("access", "access is mandatory");
        }
        if (request.validUntil() == null) {
            throw ConsentRequestException.formatError("validUntil", "validUntil is mandatory");
        }
        // "validUntil today is accepted" - only a date strictly before today is refused.
        if (request.validUntil().isBefore(today)) {
            throw ConsentRequestException.formatError(
                    "validUntil", "validUntil must not be in the past");
        }
        if (request.frequencyPerDay() < 1) {
            throw ConsentRequestException.formatError(
                    "frequencyPerDay", "frequencyPerDay must be at least 1");
        }
        if (!request.recurringIndicator() && request.frequencyPerDay() != 1) {
            throw ConsentRequestException.formatError("frequencyPerDay",
                    "frequencyPerDay must be 1 when recurringIndicator is false");
        }
        // Beyond the cap is shortened, not refused - so is the 9999-12-31 sentinel.
        LocalDate cap = today.plusDays(limits.maxValidityDays());
        return request.validUntil().isAfter(cap) ? cap : request.validUntil();
    }

    private int frequencyOf(ConsentRequest request) {
        return Math.min(request.frequencyPerDay(), limits.maxFrequencyPerDay());
    }

    public Optional<Consent> find(ConsentId id) {
        return Optional.ofNullable(consents.get(id.value()));
    }

    /**
     * Finds a consent the calling TPP owns.
     *
     * @throws ConsentRequestException {@code CONSENT_UNKNOWN} when it does not exist or
     *     belongs to someone else — the same answer either way, so ownership does not leak
     */
    public Consent require(ConsentId id, OrganizationIdentifier caller) {
        Consent consent = consents.get(id.value());
        if (consent == null || !consent.tppId().equals(caller)) {
            throw ConsentRequestException.consentUnknown(id.value());
        }
        return consent;
    }

    public Optional<Authorisation> findAuthorisation(AuthorisationId id) {
        return Optional.ofNullable(authorisations.get(id.value()));
    }

    /**
     * The authorisation of a consent, checked to belong to it.
     *
     * @throws ConsentRequestException {@code CONSENT_UNKNOWN} when the authorisation
     *     exists but under a different consent — the case
     *     {@code GET /v1/consents/999cons000/authorisations/123auth567} answers 403 for
     */
    public Authorisation requireAuthorisation(ConsentId consentId, AuthorisationId id) {
        Authorisation authorisation = authorisations.get(id.value());
        if (authorisation == null || !authorisation.consentId().equals(consentId)) {
            throw ConsentRequestException.consentUnknown(consentId.value());
        }
        return authorisation;
    }

    /** The authorisation ids of one consent, for {@code GET .../authorisations}. */
    public List<String> authorisationIdsOf(ConsentId consentId) {
        return authorisations.values().stream()
                .filter(a -> a.consentId().equals(consentId))
                .map(a -> a.id().value())
                .sorted()
                .toList();
    }

    /**
     * What the interface answers a creation with: the consent, its authorisation, and
     * whether a {@code confirmation} link belongs in {@code _links}.
     */
    public record Created(Consent consent, Authorisation authorisation,
            boolean confirmationRequired) {
    }
}
