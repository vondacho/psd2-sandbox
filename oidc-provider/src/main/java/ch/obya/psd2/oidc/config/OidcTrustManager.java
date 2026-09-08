package ch.obya.psd2.oidc.config;

import ch.obya.psd2.mtls.ChainOnlyTrustManager;
import java.net.Socket;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.List;
import javax.net.ssl.SSLEngine;
import javax.net.ssl.X509ExtendedTrustManager;

/**
 * Tomcat's trust-manager hook takes a class name and a no-argument constructor, so the
 * anchors arrive through a static. One such class per process; the logic is shared.
 */
public final class OidcTrustManager extends X509ExtendedTrustManager {

    private static volatile List<X509Certificate> anchors = List.of();

    private final ChainOnlyTrustManager delegate;

    public OidcTrustManager() {
        this.delegate = new ChainOnlyTrustManager(anchors);
    }

    static void useAnchors(List<X509Certificate> trustAnchors) {
        anchors = List.copyOf(trustAnchors);
    }

    @Override
    public X509Certificate[] getAcceptedIssuers() {
        return delegate.getAcceptedIssuers();
    }

    @Override
    public void checkClientTrusted(X509Certificate[] c, String a) throws CertificateException {
        delegate.checkClientTrusted(c, a);
    }

    @Override
    public void checkClientTrusted(X509Certificate[] c, String a, Socket s)
            throws CertificateException {
        delegate.checkClientTrusted(c, a, s);
    }

    @Override
    public void checkClientTrusted(X509Certificate[] c, String a, SSLEngine e)
            throws CertificateException {
        delegate.checkClientTrusted(c, a, e);
    }

    @Override
    public void checkServerTrusted(X509Certificate[] c, String a) throws CertificateException {
        delegate.checkServerTrusted(c, a);
    }

    @Override
    public void checkServerTrusted(X509Certificate[] c, String a, Socket s)
            throws CertificateException {
        delegate.checkServerTrusted(c, a, s);
    }

    @Override
    public void checkServerTrusted(X509Certificate[] c, String a, SSLEngine e)
            throws CertificateException {
        delegate.checkServerTrusted(c, a, e);
    }
}
