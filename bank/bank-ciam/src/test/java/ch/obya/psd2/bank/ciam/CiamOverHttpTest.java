package ch.obya.psd2.bank.ciam;

import ch.obya.psd2.bank.ciam.appl.*;
import ch.obya.psd2.bank.ciam.domain.*;

import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.security.interfaces.ECPublicKey;
import java.security.spec.ECGenParameterSpec;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The CIAM as a running process: brokered start, login, account selection, challenge,
 * and a device signing with a real P-256 key over HTTP.
 *
 * <p>Consent management is replaced by a recording double, because what is under test is
 * the CIAM's own surface; the join between the two processes has its own test in
 * {@code bank-xs2a}.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class CiamOverHttpTest {

    /** Captures what the CIAM would have posted to consent management. */
    static final class RecordingDouble implements AuthorisationRecorder {
        String consentId;
        String authorisationId;
        String psuId;
        List<DynamicLink.SelectedAccount> accounts;

        @Override
        public Recorded record(String consentId, String authorisationId, String psuId,
                String challengeId, List<DynamicLink.SelectedAccount> accounts) {
            this.consentId = consentId;
            this.authorisationId = authorisationId;
            this.psuId = psuId;
            this.accounts = accounts;
            return new Recorded("finalised", "valid");
        }
    }

    @TestConfiguration
    static class Doubles {
        @Bean
        @Primary
        RecordingDouble recorder() {
            return new RecordingDouble();
        }
    }

    private static final ObjectMapper JSON = JsonMapper.builder().build();
    private final HttpClient client = HttpClient.newHttpClient();

    @LocalServerPort
    private int port;

    @Autowired
    private RecordingDouble recorder;

    /** Plain HTTP, so the test does not depend on where Boot keeps its test client. */
    private Answer get(String path) {
        return send(HttpRequest.newBuilder(URI.create(base() + path)).GET());
    }

    private Answer post(String path, Object body) {
        try {
            return send(HttpRequest.newBuilder(URI.create(base() + path))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(
                            body == null ? "{}" : JSON.writeValueAsString(body))));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private String base() {
        return "http://localhost:" + port;
    }

    private Answer send(HttpRequest.Builder request) {
        try {
            HttpResponse<String> response =
                    client.send(request.build(), HttpResponse.BodyHandlers.ofString());
            Map<?, ?> body = response.body() == null || response.body().isBlank()
                    ? Map.of() : JSON.readValue(response.body(), Map.class);
            return new Answer(response.statusCode(), body);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private record Answer(int status, Map<?, ?> body) {
    }

    private KeyPair deviceKey;

    @BeforeEach
    void generateDeviceKey() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("EC");
        generator.initialize(new ECGenParameterSpec("secp256r1"));
        deviceKey = generator.generateKeyPair();
    }

    @Test
    @DisplayName("The whole CIAM journey over HTTP, signed by a registered device")
    void theJourney() throws Exception {
        String deviceId = enrolAnActiveDevice();

        // The OIDC-provider brokers the PSU here, naming the consent and its authorisation.
        Map<?, ?> brokered = get("/authorize?session_id=sess-1&request_id=req-1"
                + "&consent_id=123cons456&authorisation_id=123auth567"
                + "&tpp_name=TPP%20App").body();
        assertEquals("IDENTIFIED", brokered.get("step"));
        assertEquals("TPP App", brokered.get("tppName"), "the page shows who is asking");

        Map<?, ?> loggedIn = post("/login", Map.of("sessionId", "sess-1", "psuId", "anna.mueller",
                "password", "correct horse")).body();
        assertEquals("FIRST_FACTOR_VERIFIED", loggedIn.get("step"));
        assertEquals(List.of("pwd"), loggedIn.get("amr"));

        post("/consent/selection", Map.of("sessionId", "sess-1",
                "accounts", List.of(Map.of("iban", "DE23100100100123456789",
                        "currency", "EUR"))));

        Map<?, ?> challenge = post("/sca/challenges", Map.of("sessionId", "sess-1",
                "tppId", "PSDDE-BAFIN-123456", "validUntil", "2026-12-05",
                "summary", "accounts and balances until 2026-12-05")).body();
        String challengeId = (String) challenge.get("challengeId");
        assertNotNull(challenge.get("qr"));

        // The device fetches what it must show, then signs exactly that message.
        Map<?, ?> fetched = get("/sca/challenges/" + challengeId).body();
        assertEquals("TPP App", fetched.get("tppName"));
        assertEquals("accounts and balances until 2026-12-05", fetched.get("summary"));

        Map<?, ?> approved = post("/sca/challenges/" + challengeId + "/response",
                Map.of("deviceId", deviceId,
                        "signature", sign((String) fetched.get("message")))).body();

        assertEquals("approved", approved.get("status"));
        assertEquals("finalised", approved.get("scaStatus"));
        assertEquals("valid", approved.get("consentStatus"));

        // And the outcome went to consent management with what the PSU actually chose.
        assertEquals("123cons456", recorder.consentId);
        assertEquals("123auth567", recorder.authorisationId);
        assertEquals("anna.mueller", recorder.psuId);
        assertEquals(1, recorder.accounts.size());
        assertEquals("DE23100100100123456789", recorder.accounts.getFirst().iban());
    }

    @Test
    @DisplayName("A wrong password and an unknown PSU-ID give the same message")
    void loginFailuresLookAlike() {
        get("/authorize?session_id=s2&request_id=r2&consent_id=c&authorisation_id=a");

        Answer wrongPassword = post("/login",
                Map.of("sessionId", "s2", "psuId", "anna.mueller", "password", "wrong"));
        Answer unknownPsu = post("/login",
                Map.of("sessionId", "s2", "psuId", "nobody.here", "password", "correct horse"));

        assertEquals(401, wrongPassword.status());
        assertEquals(401, unknownPsu.status());
        assertEquals(wrongPassword.body(), unknownPsu.body());
        assertEquals("Customer id or password is incorrect",
                wrongPassword.body().get("message"));
    }

    @Test
    @DisplayName("Leading and trailing spaces in the PSU-ID are ignored")
    void psuIdIsTrimmed() {
        get("/authorize?session_id=s3&request_id=r3&consent_id=c&authorisation_id=a");

        Answer response = post("/login", Map.of("sessionId", "s3",
                "psuId", "  anna.mueller  ", "password", "correct horse"));

        assertEquals(200, response.status());
    }

    @Test
    @DisplayName("Spaces inside the password are significant")
    void passwordIsNotTrimmed() {
        get("/authorize?session_id=s4&request_id=r4&consent_id=c&authorisation_id=a");

        Answer response = post("/login", Map.of("sessionId", "s4",
                "psuId", "anna.mueller", "password", "correcthorse"));

        assertEquals(401, response.status());
    }

    @Test
    @DisplayName("A newly registered device is pending until an existing SCA confirms it")
    void newDevicesArePending() {
        Map<?, ?> registered = post("/devices", registration()).body();

        assertEquals("pending", registered.get("status"));
        assertNotNull(registered.get("deviceId"));
    }

    @Test
    @DisplayName("Only a P-256 key in JWK form is accepted")
    void onlyP256IsAccepted() {
        Answer response = post("/devices", Map.of(
                "psuId", "anna.mueller", "name", "Anna's iPhone", "platform", "iOS",
                "hardwareBacked", true,
                "jwk", Map.of("kty", "RSA", "crv", "P-256", "x", "AA", "y", "BB")));

        assertEquals(400, response.status());
        assertEquals("kty must be EC", response.body().get("message"));
    }

    @Test
    @DisplayName("A pending device cannot approve; an active one can")
    void pendingDeviceCannotApprove() throws Exception {
        String pending = (String) post("/devices", registration()).body().get("deviceId");
        get("/authorize?session_id=s5&request_id=r5&consent_id=123cons456"
                + "&authorisation_id=123auth567");
        post("/login", Map.of("sessionId", "s5", "psuId", "anna.mueller",
                "password", "correct horse"));
        post("/consent/selection", Map.of("sessionId", "s5",
                "accounts", List.of(Map.of("iban", "DE23100100100123456789",
                        "currency", "EUR"))));
        String challengeId = (String) post("/sca/challenges", Map.of("sessionId", "s5",
                "tppId", "PSDDE-BAFIN-123456", "validUntil", "2026-12-05",
                "summary", "s")).body().get("challengeId");
        String message = (String) get("/sca/challenges/" + challengeId).body().get("message");

        Answer refused = post("/sca/challenges/" + challengeId + "/response",
                Map.of("deviceId", pending, "signature", sign(message)));

        assertEquals(401, refused.status());
        assertEquals("DEVICE_NOT_ACTIVE", refused.body().get("reason"));
    }

    // ---- helpers ---------------------------------------------------------------------

    private String enrolAnActiveDevice() {
        String deviceId = (String) post("/devices", registration()).body().get("deviceId");
        post("/devices/" + deviceId + "/activate", null);
        return deviceId;
    }

    private Map<String, Object> registration() {
        ECPublicKey key = (ECPublicKey) deviceKey.getPublic();
        return Map.of("psuId", "anna.mueller", "name", "Anna's iPhone", "platform", "iOS",
                "hardwareBacked", true,
                "jwk", Map.of("kty", "EC", "crv", "P-256",
                        "x", coordinate(key.getW().getAffineX()),
                        "y", coordinate(key.getW().getAffineY())));
    }

    /** A P-256 coordinate is 32 bytes, left-padded, base64url without padding. */
    private static String coordinate(java.math.BigInteger value) {
        byte[] bytes = value.toByteArray();
        byte[] fixed = new byte[32];
        int from = Math.max(0, bytes.length - 32);
        System.arraycopy(bytes, from, fixed, 32 - (bytes.length - from), bytes.length - from);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(fixed);
    }

    private String sign(String message) throws Exception {
        Signature ecdsa = Signature.getInstance("SHA256withECDSA");
        ecdsa.initSign(deviceKey.getPrivate());
        ecdsa.update(message.getBytes(StandardCharsets.UTF_8));
        return Base64.getUrlEncoder().withoutPadding().encodeToString(ecdsa.sign());
    }
}
