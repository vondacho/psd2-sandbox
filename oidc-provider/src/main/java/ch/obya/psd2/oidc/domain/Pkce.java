package ch.obya.psd2.oidc.domain;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;

/** RFC 7636 S256: the challenge is the base64url SHA-256 of the verifier. */
public final class Pkce {

    private Pkce() {
    }

    public static String challengeFor(String verifier) {
        try {
            return Base64.getUrlEncoder().withoutPadding().encodeToString(
                    MessageDigest.getInstance("SHA-256")
                            .digest(verifier.getBytes(StandardCharsets.US_ASCII)));
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 is required", e);
        }
    }

    /** Constant-time comparison: a verifier check is an authentication check. */
    public static boolean verifies(String challenge, String verifier) {
        if (challenge == null || verifier == null) {
            return false;
        }
        return MessageDigest.isEqual(
                challenge.getBytes(StandardCharsets.US_ASCII),
                challengeFor(verifier).getBytes(StandardCharsets.US_ASCII));
    }
}
