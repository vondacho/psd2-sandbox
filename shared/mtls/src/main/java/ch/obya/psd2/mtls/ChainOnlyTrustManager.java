package ch.obya.psd2.mtls;


import java.net.Socket;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.List;
import javax.net.ssl.SSLEngine;
import javax.net.ssl.X509ExtendedTrustManager;

/**
 * Trusts a client certificate on the strength of its chain alone, and deliberately does
 * not look at its validity dates or its revocation status.
 *
 * <p>This is what lets the two features coexist. The handshake feature wants a
 * certificate from an unknown CA to die at the TLS layer: "the handshake fails with
 * {@code unknown_ca}", "no HTTP response is produced". The validation feature wants an
 * expired or revoked certificate to reach the application and come back as
 * {@code 401 CERTIFICATE_EXPIRED} or {@code CERTIFICATE_REVOKED} with a
 * {@code tppMessages} body. The default trust manager cannot give both, because it fails
 * the handshake on an expired certificate too.
 *
 * <p>So: chain and signature here, everything semantic in the application's certificate validation.
 * Nothing is weakened — a certificate this accepts is still one the sandbox CA signed.
 */
public final class ChainOnlyTrustManager extends X509ExtendedTrustManager {

    private final List<X509Certificate> trustAnchors;

    public ChainOnlyTrustManager(List<X509Certificate> trustAnchors) {
        if (trustAnchors.isEmpty()) {
            throw new IllegalArgumentException("at least one trust anchor is required");
        }
        this.trustAnchors = List.copyOf(trustAnchors);
    }

    /** "Both load pki/ca.pem as the only client CA." */
    @Override
    public X509Certificate[] getAcceptedIssuers() {
        return trustAnchors.toArray(new X509Certificate[0]);
    }

    @Override
    public void checkClientTrusted(X509Certificate[] chain, String authType)
            throws CertificateException {
        verifyChain(chain);
    }

    @Override
    public void checkClientTrusted(X509Certificate[] chain, String authType, Socket socket)
            throws CertificateException {
        verifyChain(chain);
    }

    @Override
    public void checkClientTrusted(X509Certificate[] chain, String authType, SSLEngine engine)
            throws CertificateException {
        verifyChain(chain);
    }

    // Server-side trust is not this class's job; the sandbox uses the platform default
    // for outbound connections.
    @Override
    public void checkServerTrusted(X509Certificate[] chain, String authType)
            throws CertificateException {
        verifyChain(chain);
    }

    @Override
    public void checkServerTrusted(X509Certificate[] chain, String authType, Socket socket)
            throws CertificateException {
        verifyChain(chain);
    }

    @Override
    public void checkServerTrusted(X509Certificate[] chain, String authType, SSLEngine engine)
            throws CertificateException {
        verifyChain(chain);
    }

    /**
     * Accepts when the leaf is signed by a trusted anchor, or is itself one.
     *
     * @throws CertificateException which the TLS layer turns into an {@code unknown_ca}
     *     alert, closing the connection with no HTTP response
     */
    private void verifyChain(X509Certificate[] chain) throws CertificateException {
        if (chain == null || chain.length == 0) {
            throw new CertificateException("no client certificate presented");
        }
        X509Certificate leaf = chain[0];
        for (X509Certificate anchor : trustAnchors) {
            try {
                leaf.verify(anchor.getPublicKey());
                return;
            } catch (Exception notThisAnchor) {
                // try the next one; a sandbox CA may have rotated
            }
        }
        throw new CertificateException(
                "client certificate is not signed by a trusted sandbox CA");
    }
}
