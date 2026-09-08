package ch.obya.psd2.oidc.adapter.in;

import ch.obya.psd2.oidc.adapter.out.JwtSigner;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * RFC 8414 metadata and the JWK set.
 *
 * <p>This is the document the TPP reads from the consent's {@code scaOAuth} link, so it
 * is where the sandbox announces that it wants {@code tls_client_auth}, S256 PKCE and
 * certificate-bound tokens.
 */
@RestController
public class MetadataController {

    private final JwtSigner signer;
    private final String issuer;

    public MetadataController(JwtSigner signer,
            @Value("${sandbox.oidc.issuer:https://oidc-provider.sandbox}") String issuer) {
        this.signer = signer;
        this.issuer = issuer;
    }

    @GetMapping({"/.well-known/oauth-authorization-server",
                 "/.well-known/openid-configuration"})
    public Map<String, Object> metadata() {
        return Map.of(
                "issuer", issuer,
                "authorization_endpoint", issuer + "/authorize",
                "token_endpoint", issuer + "/token",
                "jwks_uri", issuer + "/jwks",
                "response_types_supported", List.of("code"),
                "grant_types_supported", List.of("authorization_code", "refresh_token"),
                "token_endpoint_auth_methods_supported", List.of("tls_client_auth"),
                "code_challenge_methods_supported", List.of("S256"),
                "tls_client_certificate_bound_access_tokens", true);
    }

    @GetMapping("/jwks")
    public Map<String, Object> jwks() {
        return signer.jwks();
    }
}
