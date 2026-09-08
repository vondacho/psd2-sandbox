package ch.obya.psd2.bank.xs2a.adapter.in;

import ch.obya.psd2.mtls.ChainOnlyTrustManager;


import java.net.Socket;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.List;
import javax.net.ssl.SSLEngine;
import javax.net.ssl.X509ExtendedTrustManager;

/**
 * Tomcat's hook for a custom trust manager takes a class name and calls a no-argument
 * constructor, so the trust anchors are handed over through a static before the connector
 * starts. Unpleasant, but it is the documented seam, and it is the only way to get
 * {@link ChainOnlyTrustManager} — which lets expired and revoked certificates through the
 * handshake so the application can answer 401 — into the server.
 */
public final class SandboxTrustManager extends X509ExtendedTrustManager {

    private static volatile List<X509Certificate> anchors = List.of();

    private final ChainOnlyTrustManager delegate;

    public SandboxTrustManager() {
        this.delegate = new ChainOnlyTrustManager(anchors);
    }

    public static void useAnchors(List<X509Certificate> trustAnchors) {
        anchors = List.copyOf(trustAnchors);
    }

    @Override
    public X509Certificate[] getAcceptedIssuers() {
        return delegate.getAcceptedIssuers();
    }

    @Override
    public void checkClientTrusted(X509Certificate[] chain, String authType)
            throws CertificateException {
        delegate.checkClientTrusted(chain, authType);
    }

    @Override
    public void checkClientTrusted(X509Certificate[] chain, String authType, Socket socket)
            throws CertificateException {
        delegate.checkClientTrusted(chain, authType, socket);
    }

    @Override
    public void checkClientTrusted(X509Certificate[] chain, String authType, SSLEngine engine)
            throws CertificateException {
        delegate.checkClientTrusted(chain, authType, engine);
    }

    @Override
    public void checkServerTrusted(X509Certificate[] chain, String authType)
            throws CertificateException {
        delegate.checkServerTrusted(chain, authType);
    }

    @Override
    public void checkServerTrusted(X509Certificate[] chain, String authType, Socket socket)
            throws CertificateException {
        delegate.checkServerTrusted(chain, authType, socket);
    }

    @Override
    public void checkServerTrusted(X509Certificate[] chain, String authType, SSLEngine engine)
            throws CertificateException {
        delegate.checkServerTrusted(chain, authType, engine);
    }
}
