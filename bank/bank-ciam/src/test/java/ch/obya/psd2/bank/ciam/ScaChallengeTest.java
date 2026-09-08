package ch.obya.psd2.bank.ciam;

import ch.obya.psd2.bank.ciam.domain.*;
import ch.obya.psd2.bank.ciam.appl.*;

import ch.obya.psd2.bank.ciam.domain.DynamicLink.SelectedAccount;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.spec.ECGenParameterSpec;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Base64;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Covers {@code verify-the-signature-against-the-registered-key.feature} and the
 * challenge rules of {@code issue-a-challenge-with-dynamic-linking.feature}.
 *
 * <p>Real P-256 keys and real ECDSA throughout — a stubbed verifier would prove nothing
 * about the property under test.
 */
class ScaChallengeTest {

    private static final Instant NOW = Instant.parse("2026-09-06T09:12:00Z");
    private static final LocalDate UNTIL = LocalDate.of(2026, 12, 5);

    private static KeyPair annaKey1;
    private static KeyPair annaKey2;
    private static KeyPair benKey;

    @BeforeAll
    static void generateKeys() throws Exception {
        annaKey1 = p256();
        annaKey2 = p256();
        benKey = p256();
    }

    private static KeyPair p256() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("EC");
        generator.initialize(new ECGenParameterSpec("secp256r1"));
        return generator.generateKeyPair();
    }

    private static RegisteredDevice device(String id, String psuId, KeyPair keys,
            DeviceStatus status) {
        return new RegisteredDevice(id, psuId, id, keys.getPublic(), true, status, NOW);
    }

    private static ScaChallenge challenge() {
        return challenge("123cons456");
    }

    private static ScaChallenge challenge(String consentId) {
        DynamicLink link = DynamicLink.forConsent(consentId, "PSDDE-BAFIN-123456",
                "TPP App (TPP Fintech GmbH)",
                List.of(new SelectedAccount("DE23100100100123456789", "EUR")), UNTIL,
                "accounts and balances until 2026-12-05");
        return new ScaChallenge("chl-01J8", "anna.mueller",
                ChallengeSubjectKind.AIS_CONSENT, consentId, link, NOW);
    }

    private static String sign(PrivateKey key, String message) throws Exception {
        Signature ecdsa = Signature.getInstance("SHA256withECDSA");
        ecdsa.initSign(key);
        ecdsa.update(message.getBytes(StandardCharsets.UTF_8));
        return Base64.getUrlEncoder().withoutPadding().encodeToString(ecdsa.sign());
    }

    // ---- the challenge record --------------------------------------------------------

    @Test
    @DisplayName("The challenge record: id, PSU, subject, 22-character nonce, 3-minute expiry")
    void theChallengeRecord() {
        ScaChallenge challenge = challenge();

        assertEquals("anna.mueller", challenge.psuId());
        assertEquals(ChallengeSubjectKind.AIS_CONSENT, challenge.subjectKind());
        assertEquals("123cons456", challenge.subjectId());
        assertEquals(22, challenge.nonce().length(), "128 bits as unpadded base64url");
        assertEquals(NOW, challenge.createdAt());
        assertEquals(NOW.plus(Duration.ofMinutes(3)), challenge.expiresAt());
        assertEquals(ChallengeStatus.PENDING, challenge.status());
    }

    @Test
    @DisplayName("Two challenges never share a nonce")
    void noncesAreUnique() {
        Set<String> nonces = new HashSet<>();
        for (int i = 0; i < 1000; i++) {
            nonces.add(challenge().nonce());
        }
        assertEquals(1000, nonces.size());
    }

    @Test
    @DisplayName("The signed message binds the challenge, the nonce and the dynamic link")
    void theSignedMessage() {
        ScaChallenge challenge = challenge();

        assertEquals("chl-01J8|" + challenge.nonce() + "|" + challenge.dynamicLink().hash(),
                challenge.messageToSign());
    }

    // ---- verification ----------------------------------------------------------------

    @Test
    @DisplayName("The nominal approval")
    void nominalApproval() throws Exception {
        ScaChallenge challenge = challenge();
        RegisteredDevice anna = device("dev-anna-1", "anna.mueller", annaKey1,
                DeviceStatus.ACTIVE);

        ScaChallenge.Outcome outcome = challenge.answer(anna,
                sign(annaKey1.getPrivate(), challenge.messageToSign()), NOW.plusSeconds(30));

        assertTrue(outcome.isApproved());
        assertEquals(ChallengeStatus.APPROVED, challenge.status());
        assertEquals("dev-anna-1", challenge.answeredByDeviceId());
        assertNotNull(challenge.signature(), "the evidence is kept for a later audit");
        assertEquals(NOW.plusSeconds(30), challenge.answeredAt());
        assertEquals(NOW.plusSeconds(30), anna.lastUsedAt());
    }

    @Test
    @DisplayName("A signature from Ben's active device")
    void anotherPsusDevice() throws Exception {
        ScaChallenge challenge = challenge();
        RegisteredDevice ben = device("dev-ben-1", "ben.weber", benKey, DeviceStatus.ACTIVE);

        assertEquals(ScaChallenge.Outcome.DEVICE_OF_ANOTHER_PSU,
                challenge.answer(ben, sign(benKey.getPrivate(), challenge.messageToSign()), NOW));
        assertEquals(ChallengeStatus.PENDING, challenge.status());
    }

    @Test
    @DisplayName("A signature from Anna's blocked device")
    void blockedDevice() throws Exception {
        ScaChallenge challenge = challenge();
        RegisteredDevice blocked = device("dev-anna-0", "anna.mueller", annaKey1,
                DeviceStatus.BLOCKED);

        assertEquals(ScaChallenge.Outcome.DEVICE_NOT_ACTIVE, challenge.answer(blocked,
                sign(annaKey1.getPrivate(), challenge.messageToSign()), NOW));
    }

    @Test
    @DisplayName("A signature from Anna's pending device")
    void pendingDevice() throws Exception {
        ScaChallenge challenge = challenge();
        RegisteredDevice pending = device("dev-anna-2", "anna.mueller", annaKey1,
                DeviceStatus.PENDING);

        assertEquals(ScaChallenge.Outcome.DEVICE_NOT_ACTIVE, challenge.answer(pending,
                sign(annaKey1.getPrivate(), challenge.messageToSign()), NOW));
    }

    @Test
    @DisplayName("A valid signature over another challenge's message")
    void signatureOverAnotherChallenge() throws Exception {
        ScaChallenge target = challenge();
        ScaChallenge other = challenge();
        RegisteredDevice anna = device("dev-anna-1", "anna.mueller", annaKey1,
                DeviceStatus.ACTIVE);

        assertEquals(ScaChallenge.Outcome.BAD_SIGNATURE, target.answer(anna,
                sign(annaKey1.getPrivate(), other.messageToSign()), NOW),
                "the nonce differs, so a replay across challenges cannot verify");
    }

    @Test
    @DisplayName("A valid signature over another consent's hash")
    void signatureOverAnotherConsent() throws Exception {
        ScaChallenge target = challenge("123cons456");
        ScaChallenge other = challenge("111cons222");
        RegisteredDevice anna = device("dev-anna-1", "anna.mueller", annaKey1,
                DeviceStatus.ACTIVE);

        assertEquals(ScaChallenge.Outcome.BAD_SIGNATURE, target.answer(anna,
                sign(annaKey1.getPrivate(), other.messageToSign()), NOW),
                "dynamic linking: approving one consent cannot approve another");
    }

    @Test
    @DisplayName("Random bytes as signature")
    void randomBytes() {
        ScaChallenge challenge = challenge();
        RegisteredDevice anna = device("dev-anna-1", "anna.mueller", annaKey1,
                DeviceStatus.ACTIVE);

        assertEquals(ScaChallenge.Outcome.BAD_SIGNATURE,
                challenge.answer(anna, "bm90LWEtc2lnbmF0dXJl", NOW));
    }

    @Test
    @DisplayName("A correct signature for an expired challenge")
    void expiredChallenge() throws Exception {
        ScaChallenge challenge = challenge();
        RegisteredDevice anna = device("dev-anna-1", "anna.mueller", annaKey1,
                DeviceStatus.ACTIVE);

        assertEquals(ScaChallenge.Outcome.EXPIRED, challenge.answer(anna,
                sign(annaKey1.getPrivate(), challenge.messageToSign()),
                NOW.plus(Duration.ofMinutes(3))));
        assertEquals(ChallengeStatus.EXPIRED, challenge.status());
    }

    @Test
    @DisplayName("A second correct signature")
    void answeredOnlyOnce() throws Exception {
        ScaChallenge challenge = challenge();
        RegisteredDevice anna = device("dev-anna-1", "anna.mueller", annaKey1,
                DeviceStatus.ACTIVE);
        String signature = sign(annaKey1.getPrivate(), challenge.messageToSign());

        assertTrue(challenge.answer(anna, signature, NOW).isApproved());

        assertEquals(ScaChallenge.Outcome.ALREADY_ANSWERED,
                challenge.answer(anna, signature, NOW.plusSeconds(1)));
        assertEquals(ChallengeStatus.APPROVED, challenge.status(),
                "a replay must neither re-approve nor undo the approval");
    }

    @Test
    @DisplayName("An unknown device id")
    void unknownDevice() {
        assertEquals(ScaChallenge.Outcome.UNKNOWN_DEVICE,
                challenge().answer(null, "c2ln", NOW));
    }

    @Test
    @DisplayName("A device id of Anna's with a signature from another of Anna's keys")
    void rightDeviceWrongKey() throws Exception {
        ScaChallenge challenge = challenge();
        RegisteredDevice anna = device("dev-anna-1", "anna.mueller", annaKey1,
                DeviceStatus.ACTIVE);

        assertEquals(ScaChallenge.Outcome.BAD_SIGNATURE, challenge.answer(anna,
                sign(annaKey2.getPrivate(), challenge.messageToSign()), NOW),
                "verification uses the key stored at enrolment, not whichever key signed");
    }

    @Test
    @DisplayName("Denying leaves the challenge final and unapprovable")
    void denied() throws Exception {
        ScaChallenge challenge = challenge();
        RegisteredDevice anna = device("dev-anna-1", "anna.mueller", annaKey1,
                DeviceStatus.ACTIVE);

        challenge.deny(NOW.plusSeconds(5));

        assertEquals(ChallengeStatus.DENIED, challenge.status());
        assertEquals(ScaChallenge.Outcome.ALREADY_ANSWERED, challenge.answer(anna,
                sign(annaKey1.getPrivate(), challenge.messageToSign()), NOW.plusSeconds(6)));
    }

    @Test
    @DisplayName("The QR payload carries the challenge and its nonce")
    void qrPayload() {
        ScaChallenge challenge = challenge();

        assertEquals("https://ciam.bank.sandbox/sca/chl-01J8#" + challenge.nonce(),
                challenge.qrPayload("https://ciam.bank.sandbox/sca"));
        assertFalse(challenge.qrPayload("https://ciam.bank.sandbox/sca")
                .contains(challenge.dynamicLink().hash()),
                "the QR carries a handle, not the approval itself");
    }
}
