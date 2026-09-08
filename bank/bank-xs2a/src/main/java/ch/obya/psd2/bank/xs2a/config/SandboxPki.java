package ch.obya.psd2.bank.xs2a.config;

import ch.obya.psd2.bank.xs2a.adapter.in.*;

import ch.obya.psd2.pki.PkiFixtures;
import ch.obya.psd2.pki.SandboxCa;
import java.nio.file.Path;
import java.security.cert.X509Certificate;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * The sandbox CA the Bank trusts, in place of the EU trusted list.
 *
 * <p>Generated in process for now so the app starts with no prerequisites. When the
 * other processes join, they read the same material from {@code target/pki} instead, so
 * that the TPP's certificate and the Bank's trust anchor come from one CA.
 */
@Configuration
public class SandboxPki {

    private static final Logger log = LoggerFactory.getLogger(SandboxPki.class);

    private final SandboxCa ca;

    /**
     * Creates the CA and writes it, the seven fixture identities and a CRL to
     * {@code sandbox.pki.directory}.
     *
     * <p>Writing them out is not a convenience: the CA lives in this process, so without
     * it nothing outside — curl, the TPP, the acceptance suite — could obtain a
     * certificate this Bank would accept, and every handshake would fail with
     * {@code certificate_unknown}.
     */
    public SandboxPki(@Value("${sandbox.pki.directory:target/pki}") String directory)
            throws Exception {
        Path out = Path.of(directory);
        this.ca = PkiFixtures.generateInto(out);
        log.info("sandbox PKI written to {} - present {}/tpp.pem with {}/tpp.key to reach "
                + "the XS2A API", out.toAbsolutePath(), directory, directory);
    }

    @Bean
    public SandboxCa sandboxCa() {
        return ca;
    }

    /** "Both load pki/ca.pem as the only client CA." */
    @Bean
    public List<X509Certificate> clientTrustAnchors() {
        return List.of(ca.certificate());
    }
}
