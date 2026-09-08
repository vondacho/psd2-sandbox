package ch.obya.psd2.oidc;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * The OIDC-provider: oidc-provider.sandbox.
 *
 * <p>A separate domain in the context map, not merely a separate context, so it keeps
 * its own process and reaches the Bank only over the internal HTTP contract.
 */
@SpringBootApplication
public class OidcProviderApplication {

    public static void main(String[] args) {
        SpringApplication.run(OidcProviderApplication.class, args);
    }
}
