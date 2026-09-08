package ch.obya.psd2.oidc.config;

import ch.obya.psd2.oidc.appl.*;
import ch.obya.psd2.oidc.domain.*;
import ch.obya.psd2.spec.OrganizationIdentifier;

import java.time.Clock;
import java.util.List;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Wires the OIDC-provider and registers the sandbox's TPP clients. */
@Configuration
public class OidcConfiguration {

    private static final Logger log = LoggerFactory.getLogger(OidcConfiguration.class);

    @Bean
    public Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    public ScopeValidation scopeValidation(ConsentLookup consents) {
        // "The refusal is logged with both client ids" - the only place an owner's
        // identity may appear, never in the response.
        return new ScopeValidation(consents,
                (clientId, message) -> log.warn("authorization refused for {}: {}",
                        clientId, message));
    }

    @Bean
    public AccessTokens accessTokens(
            @Value("${sandbox.oidc.issuer:https://oidc-provider.sandbox}") String issuer,
            @Value("${sandbox.oidc.audience:https://api.bank.sandbox/psd2}") String audience,
            @Value("${sandbox.oidc.pairwise-salt:sandbox-pairwise}") String salt) {
        return new AccessTokens(issuer, audience, salt);
    }

    @Bean
    public AuthorizationService authorizationService(Clock clock, ScopeValidation scopes) {
        AuthorizationService authorization = new AuthorizationService(clock, scopes);

        // The client id IS the organization identifier of the QWAC, and the redirect
        // URIs lie in the certificate's domain. Both come from the PKI fixtures.
        authorization.register(new ClientRegistration(
                OrganizationIdentifier.parse("PSDDE-BAFIN-123456"), "TPP Fintech GmbH",
                Set.of(Psd2Role.AISP, Psd2Role.PISP),
                List.of("https://tpp.sandbox/xs2a/callback/bank"),
                Set.of()));
        authorization.register(new ClientRegistration(
                OrganizationIdentifier.parse("PSDDE-BAFIN-654321"), "C Pay",
                Set.of(Psd2Role.PISP),
                List.of("https://tpp-c.sandbox/xs2a/callback/bank"),
                Set.of()));
        return authorization;
    }
}
