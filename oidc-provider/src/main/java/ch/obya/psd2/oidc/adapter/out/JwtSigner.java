package ch.obya.psd2.oidc.adapter.out;

import ch.obya.psd2.oidc.appl.AccessTokens;

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
import java.util.Date;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * Signs access tokens with ES256, and publishes the public half at {@code /jwks}.
 *
 * <p>Two keys are kept, current and previous. "The OIDC-provider's signing key rotates
 * without breaking verification": a token signed before a rotation still verifies,
 * because the old key stays in the JWK set until its last token has expired.
 */
@Component
public class JwtSigner {

    private volatile ECKey current;
    private volatile ECKey previous;

    public JwtSigner() throws Exception {
        this.current = newKey("oidc-2026");
    }

    private static ECKey newKey(String keyId) throws Exception {
        return new ECKeyGenerator(Curve.P_256).keyID(keyId).generate();
    }

    /** Rotates. The previous key stays published so live tokens keep verifying. */
    public void rotate(String newKeyId) throws Exception {
        previous = current;
        current = newKey(newKeyId);
    }

    public String sign(AccessTokens.Claims claims) throws Exception {
        JWTClaimsSet claimSet = new JWTClaimsSet.Builder()
                .issuer(claims.issuer())
                .subject(claims.subject())
                .audience(claims.audience())
                .claim("client_id", claims.clientId())
                .claim("scope", claims.scope())
                .claim("consent_id", claims.consentId())
                .claim("acr", claims.acr())
                .claim("amr", claims.amr())
                // RFC 8705: the token is useless without the key behind this certificate.
                .claim("cnf", Map.of("x5t#S256", claims.certificateThumbprint()))
                .issueTime(Date.from(claims.issuedAt()))
                .expirationTime(Date.from(claims.expiresAt()))
                .jwtID(claims.jti())
                .build();

        SignedJWT jwt = new SignedJWT(
                new JWSHeader.Builder(JWSAlgorithm.ES256)
                        .type(JOSEObjectType.JWT).keyID(current.getKeyID()).build(),
                claimSet);
        jwt.sign(new ECDSASigner(current));
        return jwt.serialize();
    }

    /** The public keys, current first. */
    public Map<String, Object> jwks() {
        List<ECKey> keys = previous == null
                ? List.of(current) : List.of(current, previous);
        return new JWKSet(keys.stream().map(k -> (com.nimbusds.jose.jwk.JWK) k.toPublicJWK())
                .toList()).toJSONObject();
    }
}
