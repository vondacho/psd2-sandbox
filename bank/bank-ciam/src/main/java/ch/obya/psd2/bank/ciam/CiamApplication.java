package ch.obya.psd2.bank.ciam;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * The Bank's CIAM: ciam.bank.sandbox.
 *
 * <p>A separate process from the XS2A API on purpose. That port asks every connection
 * for a client certificate; this one is browser-facing and must not, or some browsers
 * prompt the PSU to choose a certificate. It also needs its own cookie domain.
 */
@SpringBootApplication
public class CiamApplication {

    public static void main(String[] args) {
        SpringApplication.run(CiamApplication.class, args);
    }
}
