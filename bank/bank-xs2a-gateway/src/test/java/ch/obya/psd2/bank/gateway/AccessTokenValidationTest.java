package ch.obya.psd2.bank.gateway;

import ch.obya.psd2.bank.gateway.adapter.in.AccessTokenValidation;
import ch.obya.psd2.pki.IssuanceRequest;
import ch.obya.psd2.pki.PkiFixtures;
import ch.obya.psd2.pki.SandboxCa;

import com.nimbusds.jose.JOSEObjectType;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.ECDSASigner;
import com.nimbusds.jose.jwk.Curve;
import com.nimbusds.jose.jwk.ECKey;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.gen.ECKeyGenerator;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import java.security.MessageDigest;
import java.security.cert.X509Certificate;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Covers {@code validate-token-and-consent-on-every-call.feature}.
 *
 * <p>Real ES256 keys, real certificates from the {@code pki} module, real signatures —
 * the whole point of these scenarios is that the crypto holds, so stubbing it would test
 * nothing.
 */
class AccessTokenValidationTest {

    private static final Instant NOW = Instant.parse("2026-09-06T10:00:00Z");
    private static final String ISSUER = "https://oidc-provider.sandbox";
    private static final String AUDIENCE = "https://api.bank.sandbox/psd2";

    private static ECKey signingKey;
    private static ECKey otherKey;
    private static X509Certificate tppCertificate;
    private static X509Certificate cCertificate;

    private final AtomicInteger jwksFetches = new AtomicInteger();

    @BeforeAll
    static void setUp() throws Exception {
        signingKey = new ECKeyGenerator(Curve.P_256).keyID("oidc-2026").generate();
        otherKey = new ECKeyGenerator(Curve.P_256).keyID("someone-else").generate();
        SandboxCa ca = SandboxCa.create(PkiFixtures.TODAY);
        for (IssuanceRequest request : PkiFixtures.identities()) {
            X509Certificate issued = ca.issue(request).certificate();
            if (request.alias().equals("tpp")) {
                tppCertificate = issued;
            } else if (request.alias().equals("tpp-c")) {
                cCertificate = issued;
            }
        }
    }

    private AccessTokenValidation validation() {
        return new AccessTokenValidation(Clock.fixed(NOW, ZoneOffset.UTC), ISSUER, AUDIENCE,
                () -> {
                    jwksFetches.incrementAndGet();
                    return new JWKSet(signingKey.toPublicJWK());
                });
    }

    private static String thumbprint(X509Certificate certificate) throws Exception {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(
                MessageDigest.getInstance("SHA-256").digest(certificate.getEncoded()));
    }

    /** A token as the OIDC-provider would mint it, with everything overridable. */
    private String token(ECKey key, String issuer, String audience, Instant expiry,
            String thumbprint, String clientId, String scope) throws Exception {
        JWTClaimsSet.Builder claims = new JWTClaimsSet.Builder()
                .issuer(issuer).subject("pairwise-abc").audience(audience)
                .claim("client_id", clientId).claim("scope", scope)
                .claim("consent_id", "123cons456")
                .claim("acr", "urn:bank:psd2:sca").claim("amr", List.of("pwd", "hwk"))
                .issueTime(Date.from(NOW.minusSeconds(60)))
                .expirationTime(Date.from(expiry)).jwtID("jti-1");
        if (thumbprint != null) {
            claims.claim("cnf", Map.of("x5t#S256", thumbprint));
        }
        SignedJWT jwt = new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.ES256)
                .type(JOSEObjectType.JWT).keyID(key.getKeyID()).build(), claims.build());
        jwt.sign(new ECDSASigner(key));
        return "Bearer " + jwt.serialize();
    }

    private String nominalToken() throws Exception {
        return token(signingKey, ISSUER, AUDIENCE, NOW.plus(Duration.ofMinutes(5)),
                thumbprint(tppCertificate), "PSDDE-BAFIN-123456", "AIS:123cons456");
    }

    @Test
    @DisplayName("A valid token passes")
    void validToken() throws Exception {
        AccessTokenValidation.Result result = validation().validate(nominalToken(),
                tppCertificate, "PSDDE-BAFIN-123456", "123cons456");

        assertTrue(result.accepted());
        assertEquals("123cons456", result.consentId());
        assertEquals("PSDDE-BAFIN-123456", result.clientId());
    }

    @Test
    @DisplayName("A bad signature")
    void badSignature() throws Exception {
        String forged = token(otherKey, ISSUER, AUDIENCE, NOW.plusSeconds(300),
                thumbprint(tppCertificate), "PSDDE-BAFIN-123456", "AIS:123cons456")
                .replace("someone-else", "oidc-2026");   // claim the right kid

        assertEquals("TOKEN_INVALID", refusalCode(forged));
    }

    @Test
    @DisplayName("alg none")
    void algNone() {
        String none = "Bearer " + Base64.getUrlEncoder().withoutPadding()
                .encodeToString("{\"alg\":\"none\"}".getBytes()) + ".e30.";

        assertEquals("TOKEN_INVALID", refusalCode(none));
    }

    @Test
    @DisplayName("An unknown kid — the JWKS is refetched once, then refused")
    void unknownKid() throws Exception {
        AccessTokenValidation validation = validation();
        // Warm the cache with a good token, so the next fetch is a genuine refetch and
        // not just the first load.
        validation.validate(nominalToken(), tppCertificate, "PSDDE-BAFIN-123456",
                "123cons456");
        int afterWarmUp = jwksFetches.get();

        String unknown = token(otherKey, ISSUER, AUDIENCE, NOW.plusSeconds(300),
                thumbprint(tppCertificate), "PSDDE-BAFIN-123456", "AIS:123cons456");

        assertEquals("TOKEN_INVALID", validation.validate(unknown, tppCertificate,
                "PSDDE-BAFIN-123456", "123cons456").code());
        assertEquals(afterWarmUp + 1, jwksFetches.get(),
                "refetched exactly once: a key rotation must not need a restart, but an "
                        + "unknown kid must not become an unbounded fetch either");
    }

    @Test
    @DisplayName("Expired")
    void expired() throws Exception {
        String expired = token(signingKey, ISSUER, AUDIENCE, NOW.minusSeconds(1),
                thumbprint(tppCertificate), "PSDDE-BAFIN-123456", "AIS:123cons456");

        assertEquals("TOKEN_EXPIRED", refusalCode(expired));
    }

    @Test
    @DisplayName("Wrong audience")
    void wrongAudience() throws Exception {
        String wrong = token(signingKey, ISSUER, "https://someone.else", NOW.plusSeconds(300),
                thumbprint(tppCertificate), "PSDDE-BAFIN-123456", "AIS:123cons456");

        assertEquals("TOKEN_INVALID", refusalCode(wrong));
    }

    @Test
    @DisplayName("Wrong issuer")
    void wrongIssuer() throws Exception {
        String wrong = token(signingKey, "https://evil.example", AUDIENCE,
                NOW.plusSeconds(300), thumbprint(tppCertificate), "PSDDE-BAFIN-123456",
                "AIS:123cons456");

        assertEquals("TOKEN_INVALID", refusalCode(wrong));
    }

    @Test
    @DisplayName("No Authorization header, and a token in the query string")
    void noBearer() {
        assertEquals("TOKEN_INVALID", refusalCode(null));
        assertEquals("TOKEN_INVALID", refusalCode("access_token=eyJ..."),
                "only the Authorization header is read, so a token in the URL is not a token");
    }

    @Test
    @DisplayName("The TPP's token over C's certificate")
    void tokenOverAnotherCertificate() throws Exception {
        AccessTokenValidation.Result result = validation().validate(nominalToken(),
                cCertificate, "PSDDE-BAFIN-654321", "123cons456");

        assertFalse(result.accepted());
        assertEquals("TOKEN_INVALID", result.code());
    }

    @Test
    @DisplayName("A token without cnf")
    void noConfirmation() throws Exception {
        String unbound = token(signingKey, ISSUER, AUDIENCE, NOW.plusSeconds(300),
                null, "PSDDE-BAFIN-123456", "AIS:123cons456");

        assertEquals("TOKEN_INVALID", refusalCode(unbound));
    }

    @Test
    @DisplayName("A token whose client_id is not the certificate's organizationIdentifier")
    void clientIdMismatch() throws Exception {
        String mismatched = token(signingKey, ISSUER, AUDIENCE, NOW.plusSeconds(300),
                thumbprint(tppCertificate), "PSDDE-BAFIN-654321", "AIS:123cons456");

        assertEquals("TOKEN_INVALID", validation().validate(mismatched, tppCertificate,
                "PSDDE-BAFIN-123456", "123cons456").code());
    }

    @Test
    @DisplayName("Matching scope and header passes; a mismatch does not")
    void scopeMustNameTheConsent() throws Exception {
        assertTrue(validation().validate(nominalToken(), tppCertificate,
                "PSDDE-BAFIN-123456", "123cons456").accepted());
        assertEquals("TOKEN_INVALID", validation().validate(nominalToken(), tppCertificate,
                "PSDDE-BAFIN-123456", "111cons222").code());
    }

    @Test
    @DisplayName("A PIS token on an AIS endpoint")
    void pisTokenOnAisEndpoint() throws Exception {
        String pis = token(signingKey, ISSUER, AUDIENCE, NOW.plusSeconds(300),
                thumbprint(tppCertificate), "PSDDE-BAFIN-123456", "PIS:pay001");

        assertEquals("TOKEN_INVALID", refusalCode(pis),
                "the wrong token, reported as a token problem and not a consent one");
    }

    @Test
    @DisplayName("A token that is never valid is refused before any consent is looked up")
    void orderIsTokenBeforeConsent() throws Exception {
        String expired = token(signingKey, ISSUER, AUDIENCE, NOW.minusSeconds(1),
                thumbprint(tppCertificate), "PSDDE-BAFIN-123456", "AIS:999cons000");

        // The consent named does not exist, but the answer is about the token: reporting
        // CONSENT_UNKNOWN would tell an unauthenticated caller whether a consent exists.
        assertEquals("TOKEN_EXPIRED", refusalCode(expired));
    }

    private String refusalCode(String authorization) {
        try {
            return validation().validate(authorization, tppCertificate,
                    "PSDDE-BAFIN-123456", "123cons456").code();
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
