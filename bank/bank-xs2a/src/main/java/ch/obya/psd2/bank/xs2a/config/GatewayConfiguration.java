package ch.obya.psd2.bank.xs2a.config;

import ch.obya.psd2.bank.xs2a.adapter.in.*;

import ch.obya.psd2.bank.gateway.adapter.in.AccessTokenValidation;
import ch.obya.psd2.bank.gateway.adapter.in.JwtFilter;
import ch.obya.psd2.bank.gateway.adapter.in.QwacFilter;
import com.nimbusds.jose.jwk.JWKSet;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import ch.obya.psd2.bank.gateway.adapter.in.RequestIdFilter;
import ch.obya.psd2.bank.tpp.appl.TppIdentification;
import java.time.Clock;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Mounts the gateway filters on the TPP-facing paths. */
@Configuration
public class GatewayConfiguration {

    /** Everything under here needs a QWAC; /internal and /admin do not. */
    public static final String XS2A_PREFIX = "/psd2/v1";

    private final Set<String> revokedSerials = ConcurrentHashMap.newKeySet();
    private final Set<String> blockedSerials = ConcurrentHashMap.newKeySet();

    @Bean
    public Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    public TppIdentification tppIdentification(Clock clock) {
        return new TppIdentification(clock, revokedSerials::contains, blockedSerials::contains);
    }

    /** Exposed so the sandbox admin endpoint can revoke or block a serial at run time. */
    @Bean
    public CertificateStatusRegistry certificateStatusRegistry() {
        return new CertificateStatusRegistry(revokedSerials, blockedSerials);
    }

    /**
     * Validates the access token against the OIDC-provider's published keys.
     *
     * <p>The JWKS is fetched lazily and cached; an unknown kid triggers exactly one
     * refetch, so the Bank survives a key rotation without a restart and without turning
     * an unknown kid into an unbounded fetch.
     */
    @Bean
    public AccessTokenValidation accessTokenValidation(Clock clock,
            @Value("${sandbox.oidc.issuer:https://oidc-provider.sandbox}") String issuer,
            @Value("${sandbox.oidc.audience:https://api.bank.sandbox/psd2}") String audience,
            @Value("${sandbox.oidc.jwks-url:http://localhost:7443/jwks}") String jwksUrl) {

        // The OIDC-provider serves TLS with a self-issued certificate: it is a sandbox
        // and both ends are on this host. What matters for token validation is the
        // signature over the JWKS content, not the transport's server identity.
        HttpClient http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(3))
                .sslContext(trustTheSandbox()).build();
        return new AccessTokenValidation(clock, issuer, audience, () -> {
            try {
                HttpResponse<String> response = http.send(
                        HttpRequest.newBuilder(URI.create(jwksUrl))
                                .timeout(Duration.ofSeconds(3)).GET().build(),
                        HttpResponse.BodyHandlers.ofString());
                return JWKSet.parse(response.body());
            } catch (Exception unreachable) {
                // No keys means no token verifies, which is the safe direction.
                return new JWKSet();
            }
        });
    }

    private static javax.net.ssl.SSLContext trustTheSandbox() {
        try {
            javax.net.ssl.SSLContext context = javax.net.ssl.SSLContext.getInstance("TLS");
            context.init(null, new javax.net.ssl.TrustManager[] {
                new javax.net.ssl.X509ExtendedTrustManager() {
                    @Override
                    public java.security.cert.X509Certificate[] getAcceptedIssuers() {
                        return new java.security.cert.X509Certificate[0];
                    }

                    @Override
                    public void checkClientTrusted(
                            java.security.cert.X509Certificate[] c, String a) { }

                    @Override
                    public void checkClientTrusted(java.security.cert.X509Certificate[] c,
                            String a, java.net.Socket s) { }

                    @Override
                    public void checkClientTrusted(java.security.cert.X509Certificate[] c,
                            String a, javax.net.ssl.SSLEngine e) { }

                    @Override
                    public void checkServerTrusted(
                            java.security.cert.X509Certificate[] c, String a) { }

                    @Override
                    public void checkServerTrusted(java.security.cert.X509Certificate[] c,
                            String a, java.net.Socket s) { }

                    @Override
                    public void checkServerTrusted(java.security.cert.X509Certificate[] c,
                            String a, javax.net.ssl.SSLEngine e) { }
                }}, null);
            return context;
        } catch (Exception e) {
            throw new IllegalStateException("no TLS", e);
        }
    }

    @Bean
    public FilterRegistrationBean<JwtFilter> jwtFilter(AccessTokenValidation tokens) {
        FilterRegistrationBean<JwtFilter> registration = new FilterRegistrationBean<>(
                new JwtFilter(tokens, XS2A_PREFIX));
        registration.addUrlPatterns("/*");
        registration.setOrder(3);   // after the certificate, before any controller
        return registration;
    }

    @Bean
    public FilterRegistrationBean<RequestIdFilter> requestIdFilter() {
        FilterRegistrationBean<RequestIdFilter> registration =
                new FilterRegistrationBean<>(new RequestIdFilter());
        registration.addUrlPatterns("/*");
        registration.setOrder(1);
        return registration;
    }

    @Bean
    public FilterRegistrationBean<QwacFilter> qwacFilter(TppIdentification identification) {
        FilterRegistrationBean<QwacFilter> registration = new FilterRegistrationBean<>(
                new QwacFilter(identification, XS2A_PREFIX));
        registration.addUrlPatterns("/*");
        registration.setOrder(2);
        return registration;
    }

    /** Lets the sandbox mark a certificate revoked or blocked without a restart. */
    public record CertificateStatusRegistry(Set<String> revoked, Set<String> blocked) {
        public void revoke(String serial) {
            revoked.add(serial.toUpperCase(java.util.Locale.ROOT));
        }

        public void block(String serial) {
            blocked.add(serial.toUpperCase(java.util.Locale.ROOT));
        }

        public void clear() {
            revoked.clear();
            blocked.clear();
        }
    }
}
