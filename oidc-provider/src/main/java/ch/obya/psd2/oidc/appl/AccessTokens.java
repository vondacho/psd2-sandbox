package ch.obya.psd2.oidc.appl;

import ch.obya.psd2.oidc.domain.*;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.cert.X509Certificate;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;

/**
 * Mints the access token, or rather decides everything about it except the signing.
 *
 * <p>Signing is the adapter's job; what belongs here is the claim set and the two rules
 * that make the token safe: it lives at most ten minutes, and it is bound to the
 * certificate presented at the token endpoint.
 */
public final class AccessTokens {

    /** "The token lives at most ten minutes." */
    public static final Duration LIFETIME = Duration.ofMinutes(10);

    private final String issuer;
    private final String audience;
    private final String pairwiseSalt;

    public AccessTokens(String issuer, String audience, String pairwiseSalt) {
        this.issuer = issuer;
        this.audience = audience;
        this.pairwiseSalt = pairwiseSalt;
    }

    /**
     * The claims of an access token.
     *
     * @param certificate the certificate presented at the token endpoint; its thumbprint
     *     becomes {@code cnf.x5t#S256}, so a stolen token is useless without the key
     */
    public Claims claimsFor(AuthorizationCode code, X509Certificate certificate,
            String jti, Instant now) {
        return new Claims(
                issuer,
                pairwiseSubjectFor(code.subject(), code.clientId()),
                audience,
                code.clientId(),
                code.target().toString(),
                code.target().resourceId(),
                code.acr(),
                code.amr(),
                thumbprintOf(certificate),
                now,
                now.plus(LIFETIME),
                jti);
    }

    /**
     * A subject the TPP cannot correlate across banks or across clients.
     *
     * <p>OIDC Core §8.1 pairwise: the same PSU seen by two clients is two subjects, so a
     * TPP learns nothing about the customer beyond its own relationship with them.
     */
    public String pairwiseSubjectFor(String psuId, String clientId) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest((pairwiseSalt + "|" + clientId + "|" + psuId)
                            .getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest).substring(0, 32);
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 is required", e);
        }
    }

    /** RFC 8705 {@code x5t#S256}: base64url of the SHA-256 of the DER, unpadded. */
    public static String thumbprintOf(X509Certificate certificate) {
        try {
            return Base64.getUrlEncoder().withoutPadding().encodeToString(
                    MessageDigest.getInstance("SHA-256").digest(certificate.getEncoded()));
        } catch (Exception e) {
            throw new IllegalStateException("cannot thumbprint the certificate", e);
        }
    }

    /** Everything the resource server needs, and nothing it does not. */
    public record Claims(String issuer, String subject, String audience, String clientId,
            String scope, String consentId, String acr, List<String> amr,
            String certificateThumbprint, Instant issuedAt, Instant expiresAt, String jti) {
    }
}
