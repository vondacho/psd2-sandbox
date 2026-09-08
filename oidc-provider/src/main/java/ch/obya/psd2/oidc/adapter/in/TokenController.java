package ch.obya.psd2.oidc.adapter.in;

import ch.obya.psd2.oidc.appl.*;
import ch.obya.psd2.oidc.domain.*;
import ch.obya.psd2.oidc.adapter.out.JwtSigner;

import jakarta.servlet.http.HttpServletRequest;
import java.security.cert.X509Certificate;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * {@code /token} — RFC 6749 §4.1.3 with RFC 8705 client authentication.
 *
 * <p>The client is authenticated by the certificate on the connection, not by a secret:
 * §13.3 mandates {@code tls_client_auth}. That same certificate is what the token is
 * bound to, so the two facts cannot drift apart.
 */
@RestController
public class TokenController {

    private static final String SERVLET_CERTIFICATE_ATTRIBUTE =
            "jakarta.servlet.request.X509Certificate";

    private final AuthorizationService authorization;
    private final AccessTokens accessTokens;
    private final JwtSigner signer;

    public TokenController(AuthorizationService authorization, AccessTokens accessTokens,
            JwtSigner signer) {
        this.authorization = authorization;
        this.accessTokens = accessTokens;
        this.signer = signer;
    }

    @PostMapping(value = "/token", consumes = "application/x-www-form-urlencoded")
    public ResponseEntity<Map<String, Object>> token(
            @RequestParam("grant_type") String grantType,
            @RequestParam(value = "code", required = false) String code,
            @RequestParam(value = "redirect_uri", required = false) String redirectUri,
            @RequestParam(value = "code_verifier", required = false) String codeVerifier,
            @RequestParam(value = "client_id", required = false) String clientId,
            HttpServletRequest request) {

        X509Certificate[] presented =
                (X509Certificate[]) request.getAttribute(SERVLET_CERTIFICATE_ATTRIBUTE);
        if (presented == null || presented.length == 0) {
            // Without a certificate there is nothing to bind the token to, and nothing
            // to authenticate the client with.
            return error(HttpStatus.UNAUTHORIZED, "invalid_client",
                    "the token endpoint requires a client certificate");
        }
        if (!"authorization_code".equals(grantType)) {
            return error(HttpStatus.BAD_REQUEST, "unsupported_grant_type", grantType);
        }

        AuthorizationService.Redeemed redeemed =
                authorization.redeem(code, clientId, redirectUri, codeVerifier);
        if (redeemed.code() == null) {
            return error(HttpStatus.BAD_REQUEST, "invalid_grant",
                    redeemed.outcome().name().toLowerCase(java.util.Locale.ROOT)
                            .replace('_', ' '));
        }

        try {
            AccessTokens.Claims claims = accessTokens.claimsFor(redeemed.code(),
                    presented[0], UUID.randomUUID().toString(), java.time.Instant.now());
            String jwt = signer.sign(claims);

            Map<String, Object> body = new LinkedHashMap<>();
            body.put("access_token", jwt);
            body.put("token_type", "Bearer");
            body.put("expires_in", AccessTokens.LIFETIME.toSeconds());
            body.put("scope", claims.scope());
            if (redeemed.code().offlineAccess()) {
                // A refresh token exists only when offline_access was asked for, and it
                // may never outlive the consent it belongs to.
                body.put("refresh_token", UUID.randomUUID().toString());
            }
            return ResponseEntity.ok(body);
        } catch (Exception e) {
            return error(HttpStatus.INTERNAL_SERVER_ERROR, "server_error", "cannot sign");
        }
    }

    private static ResponseEntity<Map<String, Object>> error(HttpStatus status,
            String error, String description) {
        return ResponseEntity.status(status).body(Map.of(
                "error", error, "error_description", description));
    }
}
