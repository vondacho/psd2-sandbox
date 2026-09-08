package ch.obya.psd2.bank.ciam;

import ch.obya.psd2.bank.ciam.domain.*;
import ch.obya.psd2.bank.ciam.appl.*;

import ch.obya.psd2.bank.ciam.domain.DynamicLink.SelectedAccount;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.security.spec.ECGenParameterSpec;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The journey the CIAM runs, covering {@code log-in-with-psu-id-and-password.feature},
 * {@code choose-the-accounts-to-share.feature} and the session rules of
 * {@code issue-a-challenge-with-dynamic-linking.feature}.
 */
class CiamJourneyTest {

    private static final Instant NOW = Instant.parse("2026-09-06T09:12:00Z");
    private static final LocalDate UNTIL = LocalDate.of(2026, 12, 5);
    private static final SelectedAccount MAIN =
            new SelectedAccount("DE23100100100123456789", "EUR");

    private final AtomicInteger challengeSequence = new AtomicInteger();
    private CiamService ciam;
    private KeyPair annaKey;

    @BeforeEach
    void setUp() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("EC");
        generator.initialize(new ECGenParameterSpec("secp256r1"));
        annaKey = generator.generateKeyPair();

        ciam = new CiamService(Clock.fixed(NOW, ZoneOffset.UTC),
                () -> "chl-%02d".formatted(challengeSequence.incrementAndGet()));
        ciam.register(new PsuIdentity("anna.mueller", "Anna Müller", "correct horse"));
        ciam.register(new RegisteredDevice("dev-anna-1", "anna.mueller", "Anna's iPhone",
                annaKey.getPublic(), true, DeviceStatus.ACTIVE, NOW));
    }

    private AuthenticationSession session() {
        return ciam.startSession("sess-1", "req-1",
                ChallengeSubjectKind.AIS_CONSENT, "123cons456");
    }

    @Test
    @DisplayName("A correct PSU-ID and password verify the first factor and record amr pwd")
    void nominalLogin() {
        AuthenticationSession session = session();

        assertTrue(ciam.logIn(session, "anna.mueller", "correct horse"));
        assertEquals(SessionStep.FIRST_FACTOR_VERIFIED, session.step());
        assertEquals(List.of("pwd"), session.authenticationMethods());
        assertEquals("anna.mueller", session.psuId().orElseThrow());
    }

    @Test
    @DisplayName("A failed login counts the failure and locks after five")
    void lockAfterFiveFailures() {
        AuthenticationSession session = session();

        for (int attempt = 1; attempt <= 5; attempt++) {
            assertFalse(ciam.logIn(session, "anna.mueller", "wrong"));
        }

        PsuIdentity anna = ciam.identity("anna.mueller").orElseThrow();
        assertEquals(PsuIdentity.Status.LOCKED, anna.status());
        assertFalse(ciam.logIn(session, "anna.mueller", "correct horse"),
                "the right password no longer helps once locked");
    }

    @Test
    @DisplayName("An unknown PSU and a wrong password are indistinguishable to the caller")
    void failuresLookAlike() {
        AuthenticationSession session = session();

        assertFalse(ciam.logIn(session, "nobody", "correct horse"));
        assertFalse(ciam.logIn(session, "anna.mueller", "wrong"));
        assertEquals(SessionStep.IDENTIFIED, session.step(), "neither advanced the session");
    }

    @Test
    @DisplayName("A successful first factor alone grants nothing")
    void firstFactorAloneIsNotEnough() {
        AuthenticationSession session = session();
        ciam.logIn(session, "anna.mueller", "correct horse");

        assertFalse(session.mayIssueIdToken());
        assertFalse(session.hasTwoIndependentFactors());
    }

    @Test
    @DisplayName("No challenge before selection")
    void noChallengeBeforeSelection() {
        AuthenticationSession session = session();
        ciam.logIn(session, "anna.mueller", "correct horse");

        assertEquals("accounts not selected",
                assertThrows(IllegalStateException.class,
                        () -> ciam.issueChallenge(session, "PSDDE-BAFIN-123456", "TPP App",
                                UNTIL, "summary")).getMessage());
    }

    @Test
    @DisplayName("A second challenge supersedes the first")
    void secondChallengeSupersedes() {
        AuthenticationSession session = session();
        ciam.logIn(session, "anna.mueller", "correct horse");
        session.accountsSelected(List.of(MAIN));

        ScaChallenge first = ciam.issueChallenge(session, "PSDDE-BAFIN-123456", "TPP App",
                UNTIL, "summary");
        ScaChallenge second = ciam.issueChallenge(session, "PSDDE-BAFIN-123456", "TPP App",
                UNTIL, "summary");

        assertEquals(ChallengeStatus.EXPIRED, first.status());
        assertEquals(ChallengeStatus.PENDING, second.status());
        assertEquals(second.challengeId(), session.challengeId().orElseThrow());
    }

    @Test
    @DisplayName("The whole journey: password, selection, challenge, signature, ID token")
    void theWholeJourney() throws Exception {
        AuthenticationSession session = session();

        assertTrue(ciam.logIn(session, "anna.mueller", "correct horse"));
        session.accountsSelected(List.of(MAIN));
        ScaChallenge challenge = ciam.issueChallenge(session, "PSDDE-BAFIN-123456",
                "TPP App (TPP Fintech GmbH)", UNTIL,
                "accounts and balances of DE23 …7 89 until 2026-12-05");

        Signature ecdsa = Signature.getInstance("SHA256withECDSA");
        ecdsa.initSign(annaKey.getPrivate());
        ecdsa.update(challenge.messageToSign().getBytes(StandardCharsets.UTF_8));
        String signature = Base64.getUrlEncoder().withoutPadding().encodeToString(ecdsa.sign());

        assertTrue(ciam.respond(challenge.challengeId(), "dev-anna-1", signature).isApproved());

        assertEquals(SessionStep.APPROVED, session.step());
        assertEquals(List.of("pwd", "hwk"), session.authenticationMethods());
        assertTrue(session.hasTwoIndependentFactors(), "knowledge plus possession");
        assertTrue(session.mayIssueIdToken());
    }

    @Test
    @DisplayName("A refused risk assessment stops the journey before any challenge")
    void riskRefusalStopsTheJourney() {
        AuthenticationSession session = session();
        ciam.logIn(session, "anna.mueller", "correct horse");

        session.riskAssessed(true);

        assertEquals(SessionStep.REFUSED, session.step());
        assertThrows(IllegalStateException.class,
                () -> session.accountsSelected(List.of(MAIN)));
    }

    @Test
    @DisplayName("Only active devices are offered the challenge")
    void onlyActiveDevices() {
        ciam.register(new RegisteredDevice("dev-anna-0", "anna.mueller", "Old phone",
                annaKey.getPublic(), true, DeviceStatus.BLOCKED, NOW));

        assertEquals(List.of("dev-anna-1"),
                ciam.activeDevicesOf("anna.mueller").stream()
                        .map(RegisteredDevice::deviceId).toList());
    }
}
