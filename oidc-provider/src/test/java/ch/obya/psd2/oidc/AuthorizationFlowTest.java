package ch.obya.psd2.oidc;

import ch.obya.psd2.oidc.appl.*;
import ch.obya.psd2.oidc.domain.*;
import ch.obya.psd2.spec.OrganizationIdentifier;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Covers {@code issue-the-authorization-code.feature} and the redemption rules of
 * {@code exchange-the-code-with-mtls-and-pkce.feature}.
 */
class AuthorizationFlowTest {

    private static final Instant NOW = Instant.parse("2026-09-06T10:00:00Z");
    private static final String REDIRECT = "https://tpp.sandbox/xs2a/callback/bank";
    private static final String VERIFIER =
            "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
    private static final String CHALLENGE =
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM";

    private AuthorizationService authorization;

    @BeforeEach
    void setUp() {
        authorization = new AuthorizationService(Clock.fixed(NOW, ZoneOffset.UTC),
                new ScopeValidation((resourceId, clientId) ->
                        new ResourceStatus(true, true, "received")));
        authorization.register(new ClientRegistration(
                OrganizationIdentifier.parse("PSDDE-BAFIN-123456"), "TPP Fintech GmbH",
                Set.of(Psd2Role.AISP, Psd2Role.PISP), List.of(REDIRECT), Set.of()));
    }

    private AuthorizationService.Started start() {
        return authorization.start("PSDDE-BAFIN-123456", REDIRECT,
                "AIS:123cons456 offline_access", "S8NJ7", CHALLENGE);
    }

    @Test
    @DisplayName("The RFC 7636 test vector: the challenge is the SHA-256 of the verifier")
    void pkceMatchesTheSpecVector() {
        assertEquals(CHALLENGE, Pkce.challengeFor(VERIFIER));
        assertTrue(Pkce.verifies(CHALLENGE, VERIFIER));
        assertFalse(Pkce.verifies(CHALLENGE, VERIFIER + "x"));
    }

    @Test
    @DisplayName("A valid request proceeds to brokering")
    void validRequestBrokers() {
        AuthorizationService.Started started = start();

        assertTrue(started.proceed());
        assertEquals("123cons456", started.target().resourceId());
    }

    @Test
    @DisplayName("An unregistered redirect URI is not redirected to")
    void unregisteredRedirectIsNotRedirected() {
        AuthorizationService.Started started = authorization.start("PSDDE-BAFIN-123456",
                "https://evil.example/cb", "AIS:123cons456", "S8NJ7", CHALLENGE);

        assertFalse(started.proceed());
        assertFalse(started.redirectSafe(),
                "redirecting to an unverified URI is how open redirectors are built");
    }

    @Test
    @DisplayName("One request yields at most one code")
    void oneCodePerRequest() {
        String requestId = start().requestId();

        assertTrue(authorization.issueCode(requestId, "anna", "acr", List.of("pwd")).isPresent());
        assertTrue(authorization.issueCode(requestId, "anna", "acr", List.of("pwd")).isEmpty());
    }

    @Test
    @DisplayName("The code is redeemed once, by the right client, with the right verifier")
    void nominalRedemption() {
        AuthorizationCode code = authorization.issueCode(start().requestId(),
                "anna.mueller", "urn:bank:psd2:sca", List.of("pwd", "hwk")).orElseThrow();

        assertTrue(authorization.redeem(code.code(), "PSDDE-BAFIN-123456", REDIRECT, VERIFIER)
                .outcome().isOk());
        assertEquals(AuthorizationCode.Redemption.ALREADY_REDEEMED,
                authorization.redeem(code.code(), "PSDDE-BAFIN-123456", REDIRECT, VERIFIER)
                        .outcome());
    }

    @Test
    @DisplayName("Another client cannot redeem the code")
    void wrongClient() {
        AuthorizationCode code = authorization.issueCode(start().requestId(),
                "anna", "acr", List.of("pwd")).orElseThrow();

        assertEquals(AuthorizationCode.Redemption.WRONG_CLIENT,
                authorization.redeem(code.code(), "PSDDE-BAFIN-654321", REDIRECT, VERIFIER)
                        .outcome());
    }

    @Test
    @DisplayName("A different redirect URI at redemption is refused")
    void wrongRedirectUri() {
        AuthorizationCode code = authorization.issueCode(start().requestId(),
                "anna", "acr", List.of("pwd")).orElseThrow();

        assertEquals(AuthorizationCode.Redemption.WRONG_REDIRECT_URI,
                authorization.redeem(code.code(), "PSDDE-BAFIN-123456",
                        REDIRECT + "/other", VERIFIER).outcome());
    }

    @Test
    @DisplayName("A wrong code verifier is refused")
    void wrongVerifier() {
        AuthorizationCode code = authorization.issueCode(start().requestId(),
                "anna", "acr", List.of("pwd")).orElseThrow();

        assertEquals(AuthorizationCode.Redemption.BAD_VERIFIER,
                authorization.redeem(code.code(), "PSDDE-BAFIN-123456", REDIRECT,
                        "not-the-verifier").outcome());
    }

    @Test
    @DisplayName("The code lives 60 seconds")
    void codeExpires() {
        AuthorizationCode code = new AuthorizationCode("c", "PSDDE-BAFIN-123456", REDIRECT,
                CHALLENGE, new ScopeTarget(ScopeKind.AIS, "123cons456"), false,
                "anna", "acr", List.of("pwd"), NOW);

        assertTrue(code.redeem("PSDDE-BAFIN-123456", REDIRECT, VERIFIER,
                NOW.plusSeconds(59)).isOk());
        AuthorizationCode fresh = new AuthorizationCode("c2", "PSDDE-BAFIN-123456", REDIRECT,
                CHALLENGE, new ScopeTarget(ScopeKind.AIS, "123cons456"), false,
                "anna", "acr", List.of("pwd"), NOW);
        assertEquals(AuthorizationCode.Redemption.EXPIRED,
                fresh.redeem("PSDDE-BAFIN-123456", REDIRECT, VERIFIER, NOW.plusSeconds(61)));
    }

    @Test
    @DisplayName("The pairwise subject differs per client for the same PSU")
    void pairwiseSubject() {
        AccessTokens tokens = new AccessTokens("https://oidc-provider.sandbox",
                "https://api.bank.sandbox/psd2", "salt");

        String forA = tokens.pairwiseSubjectFor("anna.mueller", "PSDDE-BAFIN-123456");
        String forC = tokens.pairwiseSubjectFor("anna.mueller", "PSDDE-BAFIN-654321");

        assertNotEquals(forA, forC, "OIDC Core 8.1: a TPP must not correlate the PSU");
        assertEquals(forA, tokens.pairwiseSubjectFor("anna.mueller", "PSDDE-BAFIN-123456"));
        assertFalse(forA.contains("anna"), "the subject must not carry the PSU-ID");
    }

    @Test
    @DisplayName("The access token lives at most ten minutes")
    void tokenLifetime() {
        assertEquals(Duration.ofMinutes(10), AccessTokens.LIFETIME);
    }
}
