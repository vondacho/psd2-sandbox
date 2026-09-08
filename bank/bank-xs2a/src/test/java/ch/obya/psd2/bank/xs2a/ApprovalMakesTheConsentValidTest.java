package ch.obya.psd2.bank.xs2a;

import ch.obya.psd2.bank.xs2a.adapter.in.*;
import ch.obya.psd2.bank.xs2a.config.*;

import ch.obya.psd2.pki.IssuanceRequest;
import ch.obya.psd2.pki.PkiFixtures;
import ch.obya.psd2.pki.SandboxCa;
import com.fasterxml.jackson.databind.ObjectMapper;
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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The loop closed: a consent created by the TPP over mTLS, approved through the internal
 * API as the CIAM would, and then valid to read against.
 *
 * <p>This is the join between two bounded contexts over HTTP rather than by import, so it
 * is worth an end-to-end test even though both halves have unit tests.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ApprovalMakesTheConsentValidTest {

    private static final ObjectMapper JSON = new ObjectMapper();
    private static final char[] PASSWORD = "test".toCharArray();

    private final Map<String, KeyStore> clients = new HashMap<>();

    @LocalServerPort
    private int port;

    @Autowired
    private SandboxCa ca;

    @BeforeEach
    void issueClientCertificates() throws Exception {
        for (IssuanceRequest request : PkiFixtures.identities()) {
            SandboxCa.IssuedCertificate issued = ca.issue(request);
            KeyStore store = KeyStore.getInstance("PKCS12");
            store.load(null, null);
            store.setKeyEntry("client", issued.privateKey(), PASSWORD,
                    new java.security.cert.Certificate[] {
                        issued.certificate(), ca.certificate()});
            clients.put(request.alias(), store);
        }
    }

    @Test
    @DisplayName("Created, approved by the CIAM, then valid — and the accounts are accessible")
    void theLoop() throws Exception {
        String consentId = (String) JSON.readValue(createConsent().body(), Map.class)
                .get("consentId");

        assertEquals("received", statusOf(consentId));

        Map<?, ?> recorded = JSON.readValue(recordOutcome(consentId, """
                {"psuId":"anna.mueller","challengeId":"chl-01J8","accounts":[
                  {"iban":"DE23100100100123456789","currency":"EUR",
                   "accessTypes":["accounts","balances"]}]}
                """).body(), Map.class);

        assertEquals("finalised", recorded.get("scaStatus"));
        assertEquals("valid", recorded.get("consentStatus"));
        assertEquals(1, recorded.get("accessibleAccounts"));
        assertEquals(List.of(), recorded.get("trimmed"));

        assertEquals("valid", statusOf(consentId));
        assertEquals("finalised", scaStatusOf(consentId));
    }

    @Test
    @DisplayName("Access the consent never asked for is trimmed and reported")
    void trimming() throws Exception {
        String consentId = (String) JSON.readValue(createConsent().body(), Map.class)
                .get("consentId");

        Map<?, ?> recorded = JSON.readValue(recordOutcome(consentId, """
                {"psuId":"anna.mueller","challengeId":"chl-01J8","accounts":[
                  {"iban":"DE23100100100123456789","currency":"EUR",
                   "accessTypes":["accounts","balances","transactions"]}]}
                """).body(), Map.class);

        assertEquals(List.of("DE23100100100123456789:transactions"), recorded.get("trimmed"),
                "the CIAM is not the authority on what the TPP requested");
    }

    @Test
    @DisplayName("The internal contract still answers three fields after approval")
    void aclStaysThin() throws Exception {
        String consentId = (String) JSON.readValue(createConsent().body(), Map.class)
                .get("consentId");
        recordOutcome(consentId, """
                {"psuId":"anna.mueller","challengeId":"chl-01J8","accounts":[
                  {"iban":"DE23100100100123456789","currency":"EUR",
                   "accessTypes":["accounts"]}]}
                """);

        Map<?, ?> body = JSON.readValue(send(clients.get("tpp"),
                HttpRequest.newBuilder(URI.create(base() + "/internal/consents/" + consentId
                        + "?client_id=PSDDE-BAFIN-123456")).GET()).body(), Map.class);

        assertEquals(java.util.Set.of("exists", "ownedByClient", "status"), body.keySet(),
                "the PSU and the accounts must not appear here even now that they exist");
        assertEquals("valid", body.get("status"));
    }

    @Test
    @DisplayName("Two consents get different opaque resource ids for the same IBAN")
    void resourceIdsAreOpaqueAndPerConsent() throws Exception {
        String first = (String) JSON.readValue(createConsent().body(), Map.class)
                .get("consentId");
        String second = (String) JSON.readValue(createConsent().body(), Map.class)
                .get("consentId");
        String body = """
                {"psuId":"anna.mueller","challengeId":"chl-01J8","accounts":[
                  {"iban":"DE23100100100123456789","currency":"EUR",
                   "accessTypes":["accounts"]}]}
                """;

        recordOutcome(first, body);
        recordOutcome(second, body);

        assertNotEquals(first, second);
        assertTrue(statusOf(first).equals("valid") && statusOf(second).equals("valid"));
    }

    // ---- plumbing --------------------------------------------------------------------

    private String base() {
        return "https://localhost:" + port;
    }

    private HttpResponse<String> createConsent() throws Exception {
        return send(clients.get("tpp"), HttpRequest.newBuilder(
                URI.create(base() + "/psd2/v1/consents"))
                .header("Content-Type", "application/json")
                .header("X-Request-ID", "99391c7e-ad88-49ec-a2ad-99ddcb1f7756")
                .header("TPP-Redirect-URI", "https://tpp.sandbox/xs2a/callback/bank")
                .POST(HttpRequest.BodyPublishers.ofString("""
                        {"access": {"accounts": [], "balances": []},
                         "recurringIndicator": true,
                         "validUntil": "2026-12-05",
                         "frequencyPerDay": 4}
                        """)));
    }

    private HttpResponse<String> recordOutcome(String consentId, String body) throws Exception {
        return send(clients.get("tpp"), HttpRequest.newBuilder(
                URI.create(base() + "/internal/consents/" + consentId
                        + "/authorisations/" + authorisationOf(consentId)))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body)));
    }

    private String authorisationOf(String consentId) throws Exception {
        Map<?, ?> body = JSON.readValue(send(clients.get("tpp"), HttpRequest.newBuilder(
                URI.create(base() + "/psd2/v1/consents/" + consentId + "/authorisations"))
                .GET()).body(), Map.class);
        return (String) ((List<?>) body.get("authorisationIds")).getFirst();
    }

    private String statusOf(String consentId) throws Exception {
        return (String) JSON.readValue(send(clients.get("tpp"), HttpRequest.newBuilder(
                URI.create(base() + "/psd2/v1/consents/" + consentId + "/status")).GET())
                .body(), Map.class).get("consentStatus");
    }

    private String scaStatusOf(String consentId) throws Exception {
        return (String) JSON.readValue(send(clients.get("tpp"), HttpRequest.newBuilder(
                URI.create(base() + "/psd2/v1/consents/" + consentId + "/authorisations/"
                        + authorisationOf(consentId))).GET()).body(), Map.class).get("scaStatus");
    }

    private HttpResponse<String> send(KeyStore store, HttpRequest.Builder request)
            throws Exception {
        KeyManagerFactory keys =
                KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
        keys.init(store, PASSWORD);
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(keys.getKeyManagers(), new TrustManager[] {acceptTheServer()}, null);
        return HttpClient.newBuilder().sslContext(context).build()
                .send(request.build(), HttpResponse.BodyHandlers.ofString());
    }

    private TrustManager acceptTheServer() {
        return new javax.net.ssl.X509ExtendedTrustManager() {
            @Override
            public X509Certificate[] getAcceptedIssuers() {
                return new X509Certificate[0];
            }

            @Override
            public void checkClientTrusted(X509Certificate[] c, String a) { }

            @Override
            public void checkClientTrusted(X509Certificate[] c, String a, java.net.Socket s) { }

            @Override
            public void checkClientTrusted(X509Certificate[] c, String a,
                    javax.net.ssl.SSLEngine e) { }

            @Override
            public void checkServerTrusted(X509Certificate[] c, String a) { }

            @Override
            public void checkServerTrusted(X509Certificate[] c, String a, java.net.Socket s) { }

            @Override
            public void checkServerTrusted(X509Certificate[] c, String a,
                    javax.net.ssl.SSLEngine e) { }
        };
    }
}
