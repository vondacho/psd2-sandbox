package ch.obya.psd2.pki;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.Base64;

/** Reads the material {@link PkiFixtures} writes, for the processes that only consume it. */
public final class PkiFiles {

    private PkiFiles() {
    }

    /**
     * The sandbox CA, as a trust anchor.
     *
     * <p>Only the certificate — the private key stays with whoever issues. A process that
     * merely needs to <em>recognise</em> the sandbox's certificates never needs to be able
     * to mint them.
     */
    public static X509Certificate readCertificate(Path pem) throws Exception {
        String text = Files.readString(pem, StandardCharsets.UTF_8);
        byte[] der = Base64.getMimeDecoder().decode(text
                .replace("-----BEGIN CERTIFICATE-----", "")
                .replace("-----END CERTIFICATE-----", "").trim());
        return (X509Certificate) CertificateFactory.getInstance("X.509")
                .generateCertificate(new ByteArrayInputStream(der));
    }
}
