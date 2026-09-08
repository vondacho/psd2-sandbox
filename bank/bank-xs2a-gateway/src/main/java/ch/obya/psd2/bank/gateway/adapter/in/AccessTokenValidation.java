package ch.obya.psd2.bank.gateway.adapter.in;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.jwk.JWK;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.ECKey;
import com.nimbusds.jose.crypto.ECDSAVerifier;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import java.security.cert.X509Certificate;
import java.time.Clock;
import java.time.Instant;
import java.util.Date;
import java.util.Map;
import java.util.Optional;
import java.util.function.Supplier;

/**
 * Validates a PSD2 access token, in the order the interface is specified to check.
 *
 * <p>"The checks run in a fixed order and only the first failure is reported": the
 * certificate (already done by {@link QwacFilter}), then the signature, then the token's
 * own claims, then the binding, then the scope, and only then the consent. The order is
 * not cosmetic — reporting {@code CONSENT_UNKNOWN} for a request whose token was never
 * valid would tell an unauthenticated caller whether a consent exists.
 */
public final class AccessTokenValidation {

    private final Clock clock;
    private final String expectedIssuer;
    private final String expectedAudience;
    private final Supplier<JWKSet> jwks;

    /** Refetched once on an unknown kid, to survive a key rotation without a restart. */
    private volatile JWKSet cached;

    public AccessTokenValidation(Clock clock, String expectedIssuer, String expectedAudience,
            Supplier<JWKSet> jwks) {
        this.clock = clock;
        this.expectedIssuer = expectedIssuer;
        this.expectedAudience = expectedAudience;
        this.jwks = jwks;
    }

    /**
     * @param authorization the raw {@code Authorization} header, or null
     * @param certificate the certificate on the connection, for the RFC 8705 binding
     * @param consentId the {@code Consent-ID} header the call is made under
     */
    public Result validate(String authorization, X509Certificate certificate,
            String clientId, String consentId) {

        if (authorization == null || !authorization.startsWith("Bearer ")) {
            // "the token is not accepted from the URL" - only this header is read, so a
            // token in the query string simply is not a token.
            return Result.refused("TOKEN_INVALID", "no bearer token");
        }
        SignedJWT jwt;
        try {
            jwt = SignedJWT.parse(authorization.substring("Bearer ".length()).trim());
        } catch (Exception e) {
            return Result.refused("TOKEN_INVALID", "the token is not a JWS");
        }

        // alg none, or anything but the algorithm we issue, is refused before any
        // key lookup: an attacker must not choose the algorithm.
        if (!JWSAlgorithm.ES256.equals(jwt.getHeader().getAlgorithm())) {
            return Result.refused("TOKEN_INVALID", "unexpected algorithm");
        }

        Optional<ECKey> key = keyFor(jwt.getHeader().getKeyID());
        if (key.isEmpty()) {
            return Result.refused("TOKEN_INVALID", "unknown signing key");
        }
        try {
            if (!jwt.verify(new ECDSAVerifier(key.get()))) {
                return Result.refused("TOKEN_INVALID", "bad signature");
            }
        } catch (Exception e) {
            return Result.refused("TOKEN_INVALID", "the signature cannot be checked");
        }

        JWTClaimsSet claims;
        try {
            claims = jwt.getJWTClaimsSet();
        } catch (Exception e) {
            return Result.refused("TOKEN_INVALID", "unreadable claims");
        }

        if (!expectedIssuer.equals(claims.getIssuer())) {
            return Result.refused("TOKEN_INVALID", "wrong issuer");
        }
        if (claims.getAudience() == null || !claims.getAudience().contains(expectedAudience)) {
            return Result.refused("TOKEN_INVALID", "wrong audience");
        }
        Instant now = clock.instant();
        Date expiry = claims.getExpirationTime();
        if (expiry == null || now.isAfter(expiry.toInstant())) {
            return Result.refused("TOKEN_EXPIRED", "the token has expired");
        }
        Date notBefore = claims.getNotBeforeTime();
        if (notBefore != null && now.isBefore(notBefore.toInstant())) {
            return Result.refused("TOKEN_INVALID", "the token is not yet valid");
        }

        // ---- binding: the token belongs to the certificate on this connection --------
        Object cnf = claims.getClaim("cnf");
        if (!(cnf instanceof Map<?, ?> confirmation)) {
            return Result.refused("TOKEN_INVALID", "the token is not certificate-bound");
        }
        String thumbprint = String.valueOf(confirmation.get("x5t#S256"));
        if (!thumbprintOf(certificate).equals(thumbprint)) {
            // Also the answer after a certificate rotation: the old token is bound to
            // the old certificate, so the TPP must refresh with the new one.
            return Result.refused("TOKEN_INVALID", "the token is bound to another certificate");
        }
        if (clientId != null && !clientId.equals(claims.getClaim("client_id"))) {
            return Result.refused("TOKEN_INVALID",
                    "client_id is not the certificate's organizationIdentifier");
        }

        // ---- scope: the token names the consent this call is made under --------------
        String scope = String.valueOf(claims.getClaim("scope"));
        if (!scope.startsWith("AIS:")) {
            // A PIS token on an AIS endpoint is not a consent problem; it is the wrong
            // token, so it is reported as one.
            return Result.refused("TOKEN_INVALID", "the token does not carry an AIS scope");
        }
        String scopedConsent = scope.substring("AIS:".length()).split("\\s+")[0];
        if (consentId != null && !scopedConsent.equals(consentId)) {
            return Result.refused("TOKEN_INVALID", "the token does not name this consent");
        }
        return Result.accepted(scopedConsent, (String) claims.getClaim("client_id"),
                claims.getSubject());
    }

    private Optional<ECKey> keyFor(String keyId) {
        Optional<ECKey> found = lookup(cached, keyId);
        if (found.isPresent()) {
            return found;
        }
        // "the Bank refetches the JWKS once": a key rotation must not need a restart,
        // but an unknown kid must not become an unbounded fetch either.
        cached = jwks.get();
        return lookup(cached, keyId);
    }

    private static Optional<ECKey> lookup(JWKSet set, String keyId) {
        if (set == null || keyId == null) {
            return Optional.empty();
        }
        JWK key = set.getKeyByKeyId(keyId);
        return key instanceof ECKey ecKey ? Optional.of(ecKey) : Optional.empty();
    }

    private static String thumbprintOf(X509Certificate certificate) {
        try {
            return java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(
                    java.security.MessageDigest.getInstance("SHA-256")
                            .digest(certificate.getEncoded()));
        } catch (Exception e) {
            return "";
        }
    }

    /** Accepted, with what the rest of the request needs, or refused with one code. */
    public record Result(boolean accepted, String consentId, String clientId, String subject,
            String code, String reason) {

        static Result accepted(String consentId, String clientId, String subject) {
            return new Result(true, consentId, clientId, subject, null, null);
        }

        static Result refused(String code, String reason) {
            return new Result(false, null, null, null, code, reason);
        }
    }
}
