package ch.obya.psd2.bank.tpp;

import ch.obya.psd2.pki.SandboxCa;
import java.math.BigInteger;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.cert.X509Certificate;
import java.security.spec.ECGenParameterSpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import org.bouncycastle.asn1.x500.X500Name;
import org.bouncycastle.asn1.x500.X500NameBuilder;
import org.bouncycastle.asn1.x500.style.BCStyle;
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter;
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;

/**
 * Issues a certificate that carries no {@code qcStatements} extension at all, which
 * {@link ch.obya.psd2.pki.SandboxCa} deliberately cannot do — it always stamps the PSD2
 * statement, because that is its whole job.
 *
 * <p>The certificate is self-signed rather than chained to the sandbox CA. That is
 * faithful to what is under test: chain validation happens in the TLS handshake, so by
 * the time {@link TppIdentification} sees a certificate the chain is already trusted.
 * What it checks is semantic, and "has no PSD2 statement" is semantic.
 */
final class CertificatesWithoutStatements {

    static {
        java.security.Security.addProvider(new BouncyCastleProvider());
    }

    private CertificatesWithoutStatements() {
    }

    static X509Certificate issue(SandboxCa unusedSandboxCa, Instant notBefore) throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("EC", "BC");
        generator.initialize(new ECGenParameterSpec("P-256"));
        KeyPair keys = generator.generateKeyPair();

        X500Name subject = new X500NameBuilder(BCStyle.INSTANCE)
                .addRDN(BCStyle.C, "DE")
                .addRDN(BCStyle.O, "TPP Fintech GmbH")
                .addRDN(BCStyle.ORGANIZATION_IDENTIFIER, "PSDDE-BAFIN-123456")
                .addRDN(BCStyle.CN, "tpp.sandbox")
                .build();

        return new JcaX509CertificateConverter().setProvider("BC").getCertificate(
                new JcaX509v3CertificateBuilder(
                        subject,
                        BigInteger.valueOf(9001),
                        Date.from(notBefore),
                        Date.from(notBefore.plus(Duration.ofDays(365))),
                        subject,
                        keys.getPublic())
                        .build(new JcaContentSignerBuilder("SHA256withECDSA")
                                .setProvider("BC").build(keys.getPrivate())));
    }
}
