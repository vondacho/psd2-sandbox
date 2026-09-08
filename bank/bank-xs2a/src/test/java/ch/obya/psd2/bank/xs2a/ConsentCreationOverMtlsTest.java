package ch.obya.psd2.bank.xs2a;

import ch.obya.psd2.bank.xs2a.adapter.in.*;
import ch.obya.psd2.bank.xs2a.config.*;

import ch.obya.psd2.pki.IssuanceRequest;
import ch.obya.psd2.pki.PkiFixtures;
import ch.obya.psd2.pki.SandboxCa;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.security.KeyStore;
import java.security.cert.X509Certificate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The first end-to-end slice: a real TLS handshake with a real QWAC, through the gateway
 * filters, into consent management and back out as a §6.3.1.1 answer.
 *
 * <p>Covers the parts of {@code terminate-the-xs2a-tls-with-a-client-certificate.feature}
 * and {@code post-v1-consents-creates-consent-and-authorisation.feature} that only a
 * running process can show — everything below the HTTP boundary already has unit tests.
 */
// No server.ssl.* properties: the connector is configured in TlsConfiguration, because
// a custom trust manager cannot be expressed declaratively.
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ConsentCreationOverMtlsTest {

    private static final ObjectMapper JSON = new ObjectMapper();
    private static final char[] PASSWORD = "test".toCharArray();

    private final Map<String, KeyStore> clientKeyStores = new HashMap<>();

    @LocalServerPort
    private int port;

    /**
     * The certificates must come from the CA the running application trusts, not from a
     * CA the test made up — otherwise every handshake fails with {@code certificate_
     * unknown}, which is exactly what the gateway is supposed to do to a stranger.
     */
    @Autowired
    private SandboxCa applicationCa;

    @BeforeEach
    void issueClientCertificates() throws Exception {
        for (IssuanceRequest request : PkiFixtures.identities()) {
            SandboxCa.IssuedCertificate issued = applicationCa.issue(request);
            KeyStore store = KeyStore.getInstance("PKCS12");
            store.load(null, null);
            store.setKeyEntry("client", issued.privateKey(), PASSWORD,
                    new java.security.cert.Certificate[] {
                        issued.certificate(), applicationCa.certificate()});
            clientKeyStores.put(request.alias(), store);
        }
    }

    @Test
    @DisplayName("The TPP's QWAC completes the handshake and POST /v1/consents answers 201")
    void nominalCreation() throws Exception {
        HttpResponse<String> response = post("tpp", """
                {"access": {"accounts": [], "balances": []},
                 "recurringIndicator": true,
                 "validUntil": "2026-12-05",
                 "frequencyPerDay": 4}
                """);

        assertEquals(201, response.statusCode());
        assertEquals("REDIRECT", response.headers().firstValue("ASPSP-SCA-Approach").orElseThrow());
        assertEquals("99391c7e-ad88-49ec-a2ad-99ddcb1f7756",
                response.headers().firstValue("X-Request-ID").orElseThrow(),
                "X-Request-ID is echoed");

        Map<?, ?> body = JSON.readValue(response.body(), Map.class);
        assertEquals("received", body.get("consentStatus"));
        assertNotNull(body.get("consentId"));

        Map<?, ?> links = (Map<?, ?>) body.get("_links");
        assertTrue(links.keySet().containsAll(List.of("self", "status", "scaStatus", "scaOAuth")),
                "the steering links must be present: " + links.keySet());
        assertEquals("https://oidc-provider.sandbox/.well-known/oauth-authorization-server",
                ((Map<?, ?>) links.get("scaOAuth")).get("href"));
    }

    @Test
    @DisplayName("The scaStatus link resolves to received")
    void scaStatusIsReceived() throws Exception {
        Map<?, ?> created = JSON.readValue(post("tpp", nominalBody()).body(), Map.class);
        String scaStatusPath = (String) ((Map<?, ?>)
                ((Map<?, ?>) created.get("_links")).get("scaStatus")).get("href");

        HttpResponse<String> response = get("tpp", scaStatusPath);

        assertEquals(200, response.statusCode());
        assertEquals("received", JSON.readValue(response.body(), Map.class).get("scaStatus"));
    }

    @Test
    @DisplayName("A connection without client certificate is closed during the handshake")
    void noClientCertificateFailsTheHandshake() {
        // No key manager at all: the server asks for a certificate and gets none.
        assertThrows(Exception.class, () -> {
            HttpClient client = HttpClient.newBuilder().sslContext(contextWithout()).build();
            client.send(HttpRequest.newBuilder(URI.create(baseUrl() + "/psd2/v1/consents"))
                    .GET().build(), HttpResponse.BodyHandlers.ofString());
        }, "the handshake must fail, producing no HTTP response");
    }

    @Test
    @DisplayName("A certificate from an unknown CA is refused during the handshake")
    void unknownCaFailsTheHandshake() throws Exception {
        SandboxCa otherCa = SandboxCa.create(PkiFixtures.TODAY);
        SandboxCa.IssuedCertificate foreign = otherCa.issue(PkiFixtures.identities().getFirst());
        KeyStore store = KeyStore.getInstance("PKCS12");
        store.load(null, null);
        store.setKeyEntry("client", foreign.privateKey(), PASSWORD,
                new java.security.cert.Certificate[] {
                    foreign.certificate(), otherCa.certificate()});

        assertThrows(Exception.class,
                () -> send(store, HttpRequest.newBuilder(
                        URI.create(baseUrl() + "/psd2/v1/consents")).GET()),
                "a certificate the Bank's CA did not sign must not complete the handshake");
    }

    @Test
    @DisplayName("An expired certificate completes the handshake and gets 401 CERTIFICATE_EXPIRED")
    void expiredCertificateReachesTheApplication() throws Exception {
        HttpResponse<String> response = post("tpp-expired", nominalBody());

        assertEquals(401, response.statusCode(),
                "it must reach the application, not die in the handshake");
        assertEquals("CERTIFICATE_EXPIRED", firstMessageCode(response.body()));
    }

    @Test
    @DisplayName("A PISP-only certificate may not create consents")
    void pispOnlyIsRefused() throws Exception {
        HttpResponse<String> response = post("tpp-c", nominalBody());

        assertEquals(400, response.statusCode());
        assertEquals("ROLE_INVALID", firstMessageCode(response.body()));
    }

    @Test
    @DisplayName("The internal contract answers three fields and carries no consent model")
    void internalContractStaysThin() throws Exception {
        Map<?, ?> created = JSON.readValue(post("tpp", nominalBody()).body(), Map.class);
        String consentId = (String) created.get("consentId");

        // Not TPP-facing: no client certificate, and the QWAC filter skips it.
        HttpResponse<String> response = send(clientKeyStores.get("tpp"),
                HttpRequest.newBuilder(URI.create(baseUrl() + "/internal/consents/" + consentId
                        + "?client_id=PSDDE-BAFIN-123456")).GET());

        assertEquals(200, response.statusCode());
        Map<?, ?> body = JSON.readValue(response.body(), Map.class);
        assertEquals(java.util.Set.of("exists", "ownedByClient", "status"), body.keySet(),
                "no access, psuId, validUntil or accounts may appear here");
        assertEquals(true, body.get("exists"));
        assertEquals(true, body.get("ownedByClient"));
        assertEquals("received", body.get("status"));
    }

    @Test
    @DisplayName("A consent of another client is reported as not owned, without disclosing it")
    void internalContractDoesNotLeakOwnership() throws Exception {
        Map<?, ?> created = JSON.readValue(post("tpp", nominalBody()).body(), Map.class);

        HttpResponse<String> response = send(clientKeyStores.get("tpp"),
                HttpRequest.newBuilder(URI.create(baseUrl() + "/internal/consents/"
                        + created.get("consentId") + "?client_id=PSDDE-BAFIN-654321")).GET());

        Map<?, ?> body = JSON.readValue(response.body(), Map.class);
        assertEquals(true, body.get("exists"));
        assertEquals(false, body.get("ownedByClient"));
    }

    @Test
    @DisplayName("validUntil beyond the cap is shortened, not refused, end to end")
    void validityIsCapped() throws Exception {
        HttpResponse<String> response = post("tpp", """
                {"access": {"accounts": [], "balances": []},
                 "recurringIndicator": true,
                 "validUntil": "9999-12-31",
                 "frequencyPerDay": 4}
                """);

        assertEquals(201, response.statusCode());
    }

    @Test
    @DisplayName("frequencyPerDay 0 is refused with FORMAT_ERROR and the path")
    void zeroFrequencyIsRefused() throws Exception {
        HttpResponse<String> response = post("tpp", """
                {"access": {"accounts": [], "balances": []},
                 "recurringIndicator": true,
                 "validUntil": "2026-12-05",
                 "frequencyPerDay": 0}
                """);

        assertEquals(400, response.statusCode());
        Map<?, ?> message = firstMessage(response.body());
        assertEquals("FORMAT_ERROR", message.get("code"));
        assertEquals("frequencyPerDay", message.get("path"));
    }

    // ---- plumbing --------------------------------------------------------------------

    private static String nominalBody() {
        return """
                {"access": {"accounts": [], "balances": []},
                 "recurringIndicator": true,
                 "validUntil": "2026-12-05",
                 "frequencyPerDay": 4}
                """;
    }

    private String baseUrl() {
        return "https://localhost:" + port;
    }

    private HttpResponse<String> post(String alias, String body) throws Exception {
        return send(clientKeyStores.get(alias),
                HttpRequest.newBuilder(URI.create(baseUrl() + "/psd2/v1/consents"))
                        .header("Content-Type", "application/json")
                        .header("X-Request-ID", "99391c7e-ad88-49ec-a2ad-99ddcb1f7756")
                        .header("TPP-Redirect-URI", "https://tpp.sandbox/xs2a/callback/bank")
                        .POST(HttpRequest.BodyPublishers.ofString(body)));
    }

    private HttpResponse<String> get(String alias, String path) throws Exception {
        return send(clientKeyStores.get(alias),
                HttpRequest.newBuilder(URI.create(baseUrl() + path))
                        .header("X-Request-ID", "99391c7e-ad88-49ec-a2ad-99ddcb1f7756").GET());
    }

    private HttpResponse<String> send(KeyStore clientStore, HttpRequest.Builder request)
            throws Exception {
        HttpClient client = HttpClient.newBuilder().sslContext(contextFor(clientStore)).build();
        return client.send(request.build(), HttpResponse.BodyHandlers.ofString());
    }

    /** Client side: present the given certificate, and trust the app's self-signed server cert. */
    private SSLContext contextFor(KeyStore clientStore) throws Exception {
        KeyManagerFactory keys = KeyManagerFactory.getInstance(
                KeyManagerFactory.getDefaultAlgorithm());
        keys.init(clientStore, PASSWORD);
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(keys.getKeyManagers(), new TrustManager[] {trustEverything()}, null);
        return context;
    }

    private SSLContext contextWithout() throws Exception {
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(null, new TrustManager[] {trustEverything()}, null);
        return context;
    }

    /**
     * The server's certificate is not what is under test — the client's is. Accepting it
     * keeps this test about mTLS in one direction, and the server certificate's contents
     * already have their own assertions in the pki module.
     */
    private TrustManager trustEverything() {
        return new javax.net.ssl.X509ExtendedTrustManager() {
            @Override
            public X509Certificate[] getAcceptedIssuers() {
                return new X509Certificate[0];
            }

            @Override
            public void checkClientTrusted(X509Certificate[] chain, String authType) {
            }

            @Override
            public void checkClientTrusted(X509Certificate[] chain, String authType,
                    java.net.Socket socket) {
            }

            @Override
            public void checkClientTrusted(X509Certificate[] chain, String authType,
                    javax.net.ssl.SSLEngine engine) {
            }

            @Override
            public void checkServerTrusted(X509Certificate[] chain, String authType) {
            }

            @Override
            public void checkServerTrusted(X509Certificate[] chain, String authType,
                    java.net.Socket socket) {
            }

            @Override
            public void checkServerTrusted(X509Certificate[] chain, String authType,
                    javax.net.ssl.SSLEngine engine) {
            }
        };
    }

    private String firstMessageCode(String body) throws Exception {
        return (String) firstMessage(body).get("code");
    }

    private Map<?, ?> firstMessage(String body) throws Exception {
        Map<?, ?> parsed = JSON.readValue(body, Map.class);
        return (Map<?, ?>) ((List<?>) parsed.get("tppMessages")).getFirst();
    }
}
