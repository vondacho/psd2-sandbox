package ch.obya.psd2.oidc.config;

import ch.obya.psd2.pki.PkiFiles;
import ch.obya.psd2.pki.PkiFixtures;
import ch.obya.psd2.pki.SandboxCa;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.cert.X509Certificate;
import java.time.Duration;
import java.util.List;
import org.apache.catalina.connector.Connector;
import org.apache.tomcat.util.net.SSLHostConfig;
import org.apache.tomcat.util.net.SSLHostConfigCertificate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.tomcat.servlet.TomcatServletWebServerFactory;
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Terminates TLS on the OIDC-provider, asking for a client certificate but not demanding
 * one.
 *
 * <p><strong>{@code want}, not {@code need}</strong> — and this differs from the Bank's
 * XS2A port deliberately. Two kinds of caller arrive here. The PSU's browser follows a
 * redirect to {@code /authorize} and has no certificate; demanding one would break the
 * journey and, in some browsers, prompt the PSU to pick a certificate. The TPP calls
 * {@code /token} and must present its QWAC, because that is what the token is bound to.
 * {@code TokenController} refuses a call with no certificate, so the requirement lands
 * where it belongs — on the endpoint that needs it, not on the connector.
 *
 * <p>The trust anchor is the sandbox CA read from the shared PKI directory, so a QWAC the
 * Bank accepts is a QWAC the OIDC-provider accepts. Only the certificate is read; the CA's
 * private key stays with the process that issues.
 */
@Configuration
public class TlsConfiguration {

    private static final Logger log = LoggerFactory.getLogger(TlsConfiguration.class);
    private static final String PASSWORD = "sandbox";

    @Bean
    public WebServerFactoryCustomizer<TomcatServletWebServerFactory> mutualTls(
            @Value("${sandbox.pki.directory:target/pki}") String pkiDirectory)
            throws Exception {

        Path ca = Path.of(pkiDirectory, "ca.pem");
        if (!Files.exists(ca)) {
            log.warn("no {} - starting without TLS; certificate-bound tokens will not work. "
                    + "Start bank-xs2a first, or point sandbox.pki.directory at its output.", ca);
            return factory -> { };
        }
        OidcTrustManager.useAnchors(List.of(PkiFiles.readCertificate(ca)));
        Path keyStore = writeServerKeyStore();

        return factory -> factory.addConnectorCustomizers(connector -> {
            connector.setScheme("https");
            connector.setSecure(true);
            connector.setProperty("SSLEnabled", "true");

            SSLHostConfig ssl = new SSLHostConfig();
            ssl.setSslProtocol("TLS");
            ssl.setProtocols("TLSv1.2+TLSv1.3");
            ssl.setCertificateVerification("optional");
            ssl.setTrustManagerClassName(OidcTrustManager.class.getName());

            SSLHostConfigCertificate certificate =
                    new SSLHostConfigCertificate(ssl, SSLHostConfigCertificate.Type.UNDEFINED);
            certificate.setCertificateKeystoreFile(keyStore.toAbsolutePath().toString());
            certificate.setCertificateKeystorePassword(PASSWORD);
            certificate.setCertificateKeystoreType("PKCS12");
            certificate.setCertificateKeyAlias("server");
            ssl.addCertificate(certificate);

            if (connector.getProtocolHandler()
                    instanceof org.apache.coyote.http11.AbstractHttp11Protocol<?> http11) {
                http11.addSslHostConfig(ssl, true);
            } else {
                connector.addSslHostConfig(ssl);
            }
        });
    }

    /**
     * The OIDC-provider's own server certificate, self-issued.
     *
     * <p>It is not signed by the sandbox CA because that CA's private key belongs to the
     * process that issues QWACs. Server identity is not what these scenarios test — the
     * client certificate is — so a self-issued server certificate is honest about what it
     * is rather than pretending to a chain it does not have.
     */
    private Path writeServerKeyStore() throws Exception {
        SandboxCa own = SandboxCa.create(PkiFixtures.TODAY);
        SandboxCa.IssuedCertificate server = own.issueServerCertificate(
                "oidc-provider.sandbox", List.of("oidc-provider.sandbox", "localhost"),
                PkiFixtures.TODAY, Duration.ofDays(365));

        KeyStore store = KeyStore.getInstance("PKCS12");
        store.load(null, null);
        store.setKeyEntry("server", server.privateKey(), PASSWORD.toCharArray(),
                new java.security.cert.Certificate[] {
                    server.certificate(), own.certificate()});

        Path path = Files.createTempFile("oidc-provider", ".p12");
        path.toFile().deleteOnExit();
        try (var out = Files.newOutputStream(path)) {
            store.store(out, PASSWORD.toCharArray());
        }
        return path;
    }
}
