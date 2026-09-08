package ch.obya.psd2.bank.xs2a.config;

import ch.obya.psd2.bank.xs2a.adapter.in.*;

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
import org.springframework.boot.tomcat.servlet.TomcatServletWebServerFactory;
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Terminates mTLS on the XS2A port.
 *
 * <p>Two things here are deliberate and easy to get wrong.
 *
 * <p><strong>{@code certificateVerification = required}.</strong> A connection with no
 * client certificate must be closed with a TLS alert and produce no HTTP response, which
 * is what the walking-skeleton feature asks for.
 *
 * <p><strong>A custom trust manager.</strong> The default one also checks validity dates
 * and would kill an expired certificate during the handshake — but the interface has to
 * answer {@code 401 CERTIFICATE_EXPIRED} with a {@code tppMessages} body, which needs the
 * request to arrive. {@link SandboxTrustManager} therefore checks the chain only, and
 * everything semantic happens in the QWAC filter.
 */
@Configuration
public class TlsConfiguration {

    private static final String PASSWORD = "sandbox";

    /**
     * A second, plain-HTTP connector for the internal API of §7.7.
     *
     * <p>Needed because {@code certificateVerification=required} is a property of the
     * connector, not of a path: the CIAM has no QWAC and never should, so it cannot
     * reach the XS2A port at all — the handshake fails with {@code certificate_required}
     * before any filter runs.
     *
     * <p>Nothing is opened up by this. The QWAC filter still guards {@code /psd2}, and on
     * this connector there is no certificate on the request, so an XS2A call arriving
     * here is refused with {@code 401 CERTIFICATE_MISSING}.
     */
    @Bean
    public WebServerFactoryCustomizer<TomcatServletWebServerFactory> internalConnector(
            @org.springframework.beans.factory.annotation.Value(
                    "${sandbox.bank.internal-port:8081}") int internalPort) {
        return factory -> {
            Connector connector = new Connector("org.apache.coyote.http11.Http11NioProtocol");
            connector.setPort(internalPort);
            connector.setScheme("http");
            connector.setSecure(false);
            // Boot 4 renamed this from addAdditionalTomcatConnectors.
            factory.addAdditionalConnectors(connector);
        };
    }

    @Bean
    public WebServerFactoryCustomizer<TomcatServletWebServerFactory> mutualTls(
            SandboxCa ca, List<X509Certificate> clientTrustAnchors) throws Exception {

        SandboxTrustManager.useAnchors(clientTrustAnchors);
        Path keyStorePath = writeServerKeyStore(ca);

        return factory -> factory.addConnectorCustomizers(connector -> {
            connector.setScheme("https");
            connector.setSecure(true);
            connector.setProperty("SSLEnabled", "true");

            SSLHostConfig ssl = new SSLHostConfig();
            ssl.setSslProtocol("TLS");
            // "TLS 1.3 is accepted", "TLS 1.2 is accepted", "TLS 1.1 is refused".
            ssl.setProtocols("TLSv1.2+TLSv1.3");
            ssl.setCertificateVerification("required");
            ssl.setTrustManagerClassName(SandboxTrustManager.class.getName());

            SSLHostConfigCertificate certificate =
                    new SSLHostConfigCertificate(ssl, SSLHostConfigCertificate.Type.UNDEFINED);
            certificate.setCertificateKeystoreFile(keyStorePath.toAbsolutePath().toString());
            certificate.setCertificateKeystorePassword(PASSWORD);
            certificate.setCertificateKeystoreType("PKCS12");
            certificate.setCertificateKeyAlias("server");
            ssl.addCertificate(certificate);

            // Replace, rather than add: setting SSLEnabled already created an empty
            // default host config, and plain addSslHostConfig would keep that one and
            // ignore this. Only the protocol handler exposes the replacing overload.
            if (connector.getProtocolHandler()
                    instanceof org.apache.coyote.http11.AbstractHttp11Protocol<?> http11) {
                http11.addSslHostConfig(ssl, true);
            } else {
                connector.addSslHostConfig(ssl);
            }
        });
    }

    /**
     * The Bank's own server certificate, issued by the same sandbox CA, with
     * {@code api.bank.sandbox} in its SAN — "the certificate's SAN contains
     * api.bank.sandbox" — plus {@code localhost} so tests can reach it.
     */
    private Path writeServerKeyStore(SandboxCa ca) throws Exception {
        SandboxCa.IssuedCertificate server = ca.issueServerCertificate(
                "api.bank.sandbox", List.of("api.bank.sandbox", "localhost"),
                PkiFixtures.TODAY, Duration.ofDays(365));

        KeyStore store = KeyStore.getInstance("PKCS12");
        store.load(null, null);
        store.setKeyEntry("server", server.privateKey(), PASSWORD.toCharArray(),
                new java.security.cert.Certificate[] {server.certificate(), ca.certificate()});

        Path path = Files.createTempFile("bank-xs2a-server", ".p12");
        path.toFile().deleteOnExit();
        try (var out = Files.newOutputStream(path)) {
            store.store(out, PASSWORD.toCharArray());
        }
        return path;
    }
}
