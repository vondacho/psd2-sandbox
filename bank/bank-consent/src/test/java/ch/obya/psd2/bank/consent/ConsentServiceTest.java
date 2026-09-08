package ch.obya.psd2.bank.consent;

import ch.obya.psd2.bank.consent.domain.*;
import ch.obya.psd2.bank.consent.appl.*;

import ch.obya.psd2.authorisation.ScaStatus;
import ch.obya.psd2.spec.OrganizationIdentifier;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Covers {@code docs/design/features/2-connect-the-bank-from-the-tpp/
 * post-v1-consents-creates-consent-and-authorisation.feature}.
 *
 * <p>Fixtures from {@code docs/design/examplemap/README.md}: today is 2026-09-06, the TPP
 * is {@code PSDDE-BAFIN-123456}, the consent of the journey is {@code 123cons456} with
 * authorisation {@code 123auth567}, validUntil 2026-12-05, frequencyPerDay 4.
 */
class ConsentServiceTest {

    private static final Instant NOW =
            LocalDate.of(2026, 9, 6).atStartOfDay(ZoneOffset.UTC).toInstant();
    private static final LocalDate TODAY = LocalDate.of(2026, 9, 6);
    private static final OrganizationIdentifier TPP =
            OrganizationIdentifier.parse("PSDDE-BAFIN-123456");
    private static final OrganizationIdentifier TPP_C =
            OrganizationIdentifier.parse("PSDDE-BAFIN-654321");

    private final Deque<String> consentIds = new ArrayDeque<>(List.of("123cons456", "111cons222"));
    private final Deque<String> authorisationIds =
            new ArrayDeque<>(List.of("123auth567", "123auth568"));
    private ConsentService service;

    @BeforeEach
    void setUp() {
        service = new ConsentService(Clock.fixed(NOW, ZoneOffset.UTC), SandboxLimits.defaults(),
                consentIds::removeFirst, authorisationIds::removeFirst);
    }

    private ConsentRequest nominal() {
        return new ConsentRequest(TPP, AccountAccess.bankOffered(), true,
                LocalDate.of(2026, 12, 5), 4, false,
                "https://tpp.sandbox/xs2a/callback/bank",
                "https://tpp.sandbox/xs2a/callback/bank?outcome=nok", null);
    }

    @Test
    @DisplayName("The nominal 201")
    void nominalCreation() {
        ConsentService.Created created = service.create(nominal());

        assertEquals("123cons456", created.consent().id().value());
        assertEquals(ConsentStatus.RECEIVED, created.consent().status());
        assertEquals(ScaApproach.REDIRECT, created.consent().scaApproach());
        assertEquals("123auth567", created.authorisation().id().value());
        assertTrue(created.consent().access().isBankOffered());
    }

    @Test
    @DisplayName("The consent stores the TPP, the redirect URIs and the PSU context")
    void creationStoresTheContext() {
        Consent consent = service.create(nominal()).consent();

        assertEquals(TPP, consent.tppId());
        assertEquals("https://tpp.sandbox/xs2a/callback/bank", consent.tppRedirectUri());
        assertEquals("https://tpp.sandbox/xs2a/callback/bank?outcome=nok",
                consent.tppNokRedirectUri());
        assertTrue(consent.psuId().isEmpty(), "psuId is empty before any login");
        assertEquals(ScaApproach.REDIRECT, consent.scaApproach());
    }

    @Test
    @DisplayName("Two requests create two distinct consents")
    void twoRequestsTwoConsents() {
        Consent first = service.create(nominal()).consent();
        Consent second = service.create(nominal()).consent();

        assertNotEquals(first.id(), second.id());
        assertEquals(ConsentStatus.RECEIVED, first.status());
        assertEquals(ConsentStatus.RECEIVED, second.status());
    }

    @Test
    @DisplayName("The confirmation link is present when the Bank is configured for confirmation")
    void confirmationIsSwitchable() {
        assertFalse(service.create(nominal()).confirmationRequired());

        service.applyLimits(SandboxLimits.defaults().withConfirmationRequired(true));
        ConsentService.Created created = service.create(nominal());

        assertTrue(created.confirmationRequired());
        assertTrue(created.authorisation().confirmationRequired());
    }

    @Test
    @DisplayName("The scaStatus link resolves to received")
    void authorisationStartsAtReceived() {
        ConsentService.Created created = service.create(nominal());

        assertEquals(ScaStatus.RECEIVED, created.authorisation().scaStatus());
        assertEquals("received", created.authorisation().scaStatus().wireName());
    }

    @Test
    @DisplayName("The authorisation list has exactly one entry")
    void oneAuthorisationPerConsent() {
        ConsentService.Created created = service.create(nominal());

        assertEquals(List.of("123auth567"),
                service.authorisationIdsOf(created.consent().id()));
    }

    @Test
    @DisplayName("The authorisation belongs to the consent — otherwise 403 CONSENT_UNKNOWN")
    void authorisationOfAnotherConsentIsUnknown() {
        ConsentService.Created created = service.create(nominal());

        ConsentRequestException refused = assertThrows(ConsentRequestException.class,
                () -> service.requireAuthorisation(new ConsentId("999cons000"),
                        created.authorisation().id()));

        assertEquals("CONSENT_UNKNOWN", refused.code());
    }

    @Test
    @DisplayName("A consent of another TPP is CONSENT_UNKNOWN, not FORBIDDEN — ownership does not leak")
    void anotherTppSeesConsentUnknown() {
        ConsentService.Created created = service.create(nominal());

        assertEquals("CONSENT_UNKNOWN",
                assertThrows(ConsentRequestException.class,
                        () -> service.require(created.consent().id(), TPP_C)).code());
    }

    // ---- body validation -------------------------------------------------------------

    @Test
    @DisplayName("validUntil yesterday is refused")
    void pastValidUntilIsRefused() {
        ConsentRequestException refused = assertThrows(ConsentRequestException.class,
                () -> service.create(withValidUntil(LocalDate.of(2026, 9, 5))));

        assertEquals("FORMAT_ERROR", refused.code());
        assertEquals("validUntil", refused.path());
    }

    @Test
    @DisplayName("validUntil today is accepted")
    void todayIsAccepted() {
        assertEquals(TODAY, service.create(withValidUntil(TODAY)).consent().validUntil());
    }

    @Test
    @DisplayName("validUntil beyond the bank's cap is shortened, not refused")
    void beyondTheCapIsShortened() {
        Consent consent = service.create(withValidUntil(LocalDate.of(2027, 9, 6))).consent();

        assertEquals(LocalDate.of(2027, 3, 5), consent.validUntil(),
                "180 days after 2026-09-06");
    }

    @Test
    @DisplayName("validUntil 9999-12-31 means 'maximum' and is shortened")
    void theMaximumSentinelIsShortened() {
        assertEquals(LocalDate.of(2027, 3, 5),
                service.create(withValidUntil(ConsentRequest.MAXIMUM)).consent().validUntil());
    }

    @Test
    @DisplayName("frequencyPerDay 0 is refused")
    void zeroFrequencyIsRefused() {
        ConsentRequestException refused = assertThrows(ConsentRequestException.class,
                () -> service.create(withFrequency(true, 0)));

        assertEquals("frequencyPerDay", refused.path());
    }

    @Test
    @DisplayName("A one-off consent with frequencyPerDay 4 is refused")
    void oneOffMustHaveFrequencyOne() {
        ConsentRequestException refused = assertThrows(ConsentRequestException.class,
                () -> service.create(withFrequency(false, 4)));

        assertEquals("frequencyPerDay must be 1 when recurringIndicator is false",
                refused.getMessage());
    }

    @Test
    @DisplayName("frequencyPerDay above the bank's maximum is capped")
    void frequencyIsCapped() {
        assertEquals(4, service.create(withFrequency(true, 10)).consent().frequencyPerDay());
    }

    @Test
    @DisplayName("A body without access is refused")
    void accessIsMandatory() {
        ConsentRequest request = new ConsentRequest(TPP, null, true,
                LocalDate.of(2026, 12, 5), 4, false, "https://tpp.sandbox/cb", null, null);

        assertEquals("access",
                assertThrows(ConsentRequestException.class, () -> service.create(request)).path());
    }

    @Test
    @DisplayName("A PSU-ID header is stored on the consent")
    void psuIdHeaderIsStored() {
        ConsentRequest request = new ConsentRequest(TPP, AccountAccess.bankOffered(), true,
                LocalDate.of(2026, 12, 5), 4, false, "https://tpp.sandbox/cb", null,
                "anna.mueller");

        assertEquals("anna.mueller", service.create(request).consent().psuId().orElseThrow());
    }

    @Test
    @DisplayName("A missing TPP-Nok-Redirect-URI is accepted")
    void nokRedirectIsOptional() {
        ConsentRequest request = new ConsentRequest(TPP, AccountAccess.bankOffered(), true,
                LocalDate.of(2026, 12, 5), 4, false, "https://tpp.sandbox/cb", null, null);

        assertEquals(ConsentStatus.RECEIVED, service.create(request).consent().status());
    }

    private ConsentRequest withValidUntil(LocalDate validUntil) {
        ConsentRequest n = nominal();
        return new ConsentRequest(n.tppId(), n.access(), n.recurringIndicator(), validUntil,
                n.frequencyPerDay(), n.combinedServiceIndicator(), n.tppRedirectUri(),
                n.tppNokRedirectUri(), n.psuId());
    }

    private ConsentRequest withFrequency(boolean recurring, int frequency) {
        ConsentRequest n = nominal();
        return new ConsentRequest(n.tppId(), n.access(), recurring, n.validUntil(), frequency,
                n.combinedServiceIndicator(), n.tppRedirectUri(), n.tppNokRedirectUri(),
                n.psuId());
    }
}
