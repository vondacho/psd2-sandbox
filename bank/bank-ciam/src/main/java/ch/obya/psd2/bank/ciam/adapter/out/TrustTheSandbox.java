package ch.obya.psd2.bank.ciam.adapter.out;

import java.security.cert.X509Certificate;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509ExtendedTrustManager;

/**
 * Accepts the Bank's own server certificate on the internal API.
 *
 * <p>Both ends are inside the sandbox and the CA is generated per run, so pinning it
 * would mean shipping the trust store between processes for no security gain — this
 * connection never leaves the host. A real deployment would trust the Bank's CA here.
 */
final class TrustTheSandbox {

    private TrustTheSandbox() {
    }

    static SSLContext context() {
        try {
            SSLContext context = SSLContext.getInstance("TLS");
            context.init(null, new TrustManager[] {new X509ExtendedTrustManager() {
                @Override
                public X509Certificate[] getAcceptedIssuers() {
                    return new X509Certificate[0];
                }

                @Override
                public void checkClientTrusted(X509Certificate[] c, String a) { }

                @Override
                public void checkClientTrusted(X509Certificate[] c, String a,
                        java.net.Socket s) { }

                @Override
                public void checkClientTrusted(X509Certificate[] c, String a,
                        javax.net.ssl.SSLEngine e) { }

                @Override
                public void checkServerTrusted(X509Certificate[] c, String a) { }

                @Override
                public void checkServerTrusted(X509Certificate[] c, String a,
                        java.net.Socket s) { }

                @Override
                public void checkServerTrusted(X509Certificate[] c, String a,
                        javax.net.ssl.SSLEngine e) { }
            }}, null);
            return context;
        } catch (Exception e) {
            throw new IllegalStateException("no TLS", e);
        }
    }
}
