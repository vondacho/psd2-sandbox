package ch.obya.psd2.pki;

import java.math.BigInteger;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PrivateKey;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import java.security.spec.ECGenParameterSpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.bouncycastle.asn1.ASN1EncodableVector;
import org.bouncycastle.asn1.DERSequence;
import org.bouncycastle.asn1.x500.X500Name;
import org.bouncycastle.asn1.x500.X500NameBuilder;
import org.bouncycastle.asn1.x500.style.BCStyle;
import org.bouncycastle.asn1.x509.BasicConstraints;
import org.bouncycastle.asn1.x509.Extension;
import org.bouncycastle.asn1.x509.ExtendedKeyUsage;
import org.bouncycastle.asn1.x509.GeneralName;
import org.bouncycastle.asn1.x509.GeneralNames;
import org.bouncycastle.asn1.x509.KeyPurposeId;
import org.bouncycastle.asn1.x509.KeyUsage;
import org.bouncycastle.cert.X509CertificateHolder;
import org.bouncycastle.cert.X509v2CRLBuilder;
import org.bouncycastle.cert.X509v3CertificateBuilder;
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter;
import org.bouncycastle.cert.jcajce.JcaX509CertificateHolder;
import org.bouncycastle.cert.jcajce.JcaX509ExtensionUtils;
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.bouncycastle.operator.ContentSigner;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;
import java.security.cert.X509CRL;
import org.bouncycastle.cert.jcajce.JcaX509CRLConverter;

/**
 * The sandbox's private certificate authority.
 *
 * <p>§13: "Private CA issuing test QWACs with a PSD2 QcStatement for {@code tpp}. The
 * Bank's gateway trusts this CA in the sandbox instead of the EU trusted list."
 *
 * <p>Everything is EC P-256 / SHA256withECDSA, matching the device keys the rest of the
 * sandbox uses. Serial numbers are sequential from a fixed start so tests can name one.
 */
public final class SandboxCa {

    static {
        java.security.Security.addProvider(new BouncyCastleProvider());
    }

    private static final String SIGNATURE_ALGORITHM = "SHA256withECDSA";
    private static final SecureRandom RANDOM = new SecureRandom();

    private final KeyPair keyPair;
    private final X509Certificate certificate;
    private final Map<String, IssuedCertificate> issued = new ConcurrentHashMap<>();
    private final Map<BigInteger, Instant> revoked = new ConcurrentHashMap<>();
    private BigInteger nextSerial;

    private SandboxCa(KeyPair keyPair, X509Certificate certificate, BigInteger firstSerial) {
        this.keyPair = keyPair;
        this.certificate = certificate;
        this.nextSerial = firstSerial;
    }

    /** Creates a fresh CA valid from {@code notBefore} for ten years. */
    public static SandboxCa create(Instant notBefore) throws Exception {
        KeyPair caKeys = generateKeyPair();
        X500Name name = new X500NameBuilder(BCStyle.INSTANCE)
                .addRDN(BCStyle.C, "DE")
                .addRDN(BCStyle.O, "PSD2 Sandbox Trust Services")
                .addRDN(BCStyle.CN, "PSD2 Sandbox Root CA")
                .build();

        JcaX509ExtensionUtils utils = new JcaX509ExtensionUtils();
        X509v3CertificateBuilder builder = new JcaX509v3CertificateBuilder(
                name,
                BigInteger.ONE,
                Date.from(notBefore),
                Date.from(notBefore.plus(Duration.ofDays(3650))),
                name,
                caKeys.getPublic())
                .addExtension(Extension.basicConstraints, true, new BasicConstraints(0))
                .addExtension(Extension.keyUsage, true,
                        new KeyUsage(KeyUsage.keyCertSign | KeyUsage.cRLSign))
                .addExtension(Extension.subjectKeyIdentifier, false,
                        utils.createSubjectKeyIdentifier(caKeys.getPublic()));

        X509Certificate ca = toCertificate(builder.build(signerFor(caKeys.getPrivate())));
        return new SandboxCa(caKeys, ca, new BigInteger("6699")); // 0x1A2B, the fixture serial
    }

    public X509Certificate certificate() {
        return certificate;
    }

    /** Issues one certificate and remembers it under its alias so it can be revoked. */
    public IssuedCertificate issue(IssuanceRequest request) throws Exception {
        KeyPair subjectKeys = generateKeyPair();
        BigInteger serial = nextSerial;
        nextSerial = nextSerial.add(BigInteger.ONE);

        X500Name subject = new X500NameBuilder(BCStyle.INSTANCE)
                .addRDN(BCStyle.C, "DE")
                .addRDN(BCStyle.O, request.organizationName())
                .addRDN(BCStyle.ORGANIZATION_IDENTIFIER, request.organizationIdentifier())
                .addRDN(BCStyle.CN, request.dnsNames().isEmpty()
                        ? request.organizationName()
                        : request.dnsNames().getFirst())
                .build();

        JcaX509ExtensionUtils utils = new JcaX509ExtensionUtils();
        X509v3CertificateBuilder builder = new JcaX509v3CertificateBuilder(
                new JcaX509CertificateHolder(certificate).getSubject(),
                serial,
                Date.from(request.notBefore()),
                Date.from(request.notAfter()),
                subject,
                subjectKeys.getPublic())
                .addExtension(Extension.basicConstraints, true, new BasicConstraints(false))
                .addExtension(Extension.subjectKeyIdentifier, false,
                        utils.createSubjectKeyIdentifier(subjectKeys.getPublic()))
                .addExtension(Extension.authorityKeyIdentifier, false,
                        utils.createAuthorityKeyIdentifier(certificate))
                .addExtension(Extension.qCStatements, false, qcStatements(request));

        if (request.kind() == CertificateKind.QSEAL) {
            // Sealing: non-repudiation, and deliberately no clientAuth, so a QSEAL can
            // never be used to open an mTLS connection.
            builder.addExtension(Extension.keyUsage, true,
                    new KeyUsage(KeyUsage.nonRepudiation | KeyUsage.digitalSignature));
        } else {
            builder.addExtension(Extension.keyUsage, true,
                            new KeyUsage(KeyUsage.digitalSignature | KeyUsage.keyEncipherment))
                    .addExtension(Extension.extendedKeyUsage, false,
                            new ExtendedKeyUsage(new KeyPurposeId[] {
                                    KeyPurposeId.id_kp_clientAuth, KeyPurposeId.id_kp_serverAuth
                            }));
        }
        if (!request.dnsNames().isEmpty()) {
            GeneralName[] names = request.dnsNames().stream()
                    .map(dns -> new GeneralName(GeneralName.dNSName, dns))
                    .toArray(GeneralName[]::new);
            builder.addExtension(Extension.subjectAlternativeName, false, new GeneralNames(names));
        }

        X509Certificate certificate =
                toCertificate(builder.build(signerFor(keyPair.getPrivate())));
        IssuedCertificate result =
                new IssuedCertificate(request.alias(), certificate, subjectKeys.getPrivate());
        issued.put(request.alias(), result);
        return result;
    }

    /**
     * Issues a plain TLS server certificate — no PSD2 statement, serverAuth only.
     *
     * <p>§13 has the sandbox CA issue the Bank's own server certificates too, so that a
     * TPP validating {@code api.bank.sandbox} has a path to the same root it presents
     * its QWAC against.
     */
    public IssuedCertificate issueServerCertificate(String commonName, List<String> dnsNames,
            Instant notBefore, Duration validity) throws Exception {
        KeyPair subjectKeys = generateKeyPair();
        BigInteger serial = nextSerial;
        nextSerial = nextSerial.add(BigInteger.ONE);

        X500Name subject = new X500NameBuilder(BCStyle.INSTANCE)
                .addRDN(BCStyle.C, "DE")
                .addRDN(BCStyle.O, "PSD2 Sandbox Bank")
                .addRDN(BCStyle.CN, commonName)
                .build();

        JcaX509ExtensionUtils utils = new JcaX509ExtensionUtils();
        X509v3CertificateBuilder builder = new JcaX509v3CertificateBuilder(
                new JcaX509CertificateHolder(certificate).getSubject(),
                serial,
                Date.from(notBefore),
                Date.from(notBefore.plus(validity)),
                subject,
                subjectKeys.getPublic())
                .addExtension(Extension.basicConstraints, true, new BasicConstraints(false))
                .addExtension(Extension.subjectKeyIdentifier, false,
                        utils.createSubjectKeyIdentifier(subjectKeys.getPublic()))
                .addExtension(Extension.authorityKeyIdentifier, false,
                        utils.createAuthorityKeyIdentifier(certificate))
                .addExtension(Extension.keyUsage, true,
                        new KeyUsage(KeyUsage.digitalSignature | KeyUsage.keyEncipherment))
                .addExtension(Extension.extendedKeyUsage, false,
                        new ExtendedKeyUsage(new KeyPurposeId[] {KeyPurposeId.id_kp_serverAuth}));

        if (!dnsNames.isEmpty()) {
            GeneralName[] names = dnsNames.stream()
                    .map(dns -> new GeneralName(GeneralName.dNSName, dns))
                    .toArray(GeneralName[]::new);
            builder.addExtension(Extension.subjectAlternativeName, false, new GeneralNames(names));
        }
        return new IssuedCertificate(commonName,
                toCertificate(builder.build(signerFor(keyPair.getPrivate()))),
                subjectKeys.getPrivate());
    }

    private static DERSequence qcStatements(IssuanceRequest request) {
        ASN1EncodableVector statements = new ASN1EncodableVector();
        statements.add(Psd2QcStatement.qcType(request.kind()));
        statements.add(Psd2QcStatement.psd2(
                request.roles(), request.ncaName(), request.ncaId()));
        return new DERSequence(statements);
    }

    /**
     * Revokes a previously issued certificate.
     *
     * @throws IllegalArgumentException {@code no certificate for <alias>} when nothing was
     *     issued under that alias — the message the CLI is specified to print
     */
    public void revoke(String alias, Instant when) {
        IssuedCertificate target = issued.get(alias);
        if (target == null) {
            throw new IllegalArgumentException("no certificate for " + alias);
        }
        revoked.put(target.certificate().getSerialNumber(), when);
    }

    /** The CRL, signed by the CA, with a {@code nextUpdate} 24 hours ahead. */
    public X509CRL crl(Instant thisUpdate) throws Exception {
        X509v2CRLBuilder builder = new X509v2CRLBuilder(
                new JcaX509CertificateHolder(certificate).getSubject(), Date.from(thisUpdate));
        builder.setNextUpdate(Date.from(thisUpdate.plus(Duration.ofHours(24))));
        revoked.forEach((serial, at) -> builder.addCRLEntry(serial, Date.from(at), 0));
        return new JcaX509CRLConverter().setProvider("BC")
                .getCRL(builder.build(signerFor(keyPair.getPrivate())));
    }

    public List<String> aliases() {
        return List.copyOf(issued.keySet());
    }

    private static KeyPair generateKeyPair() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("EC", "BC");
        generator.initialize(new ECGenParameterSpec("P-256"), RANDOM);
        return generator.generateKeyPair();
    }

    private static ContentSigner signerFor(PrivateKey key) throws Exception {
        return new JcaContentSignerBuilder(SIGNATURE_ALGORITHM).setProvider("BC").build(key);
    }

    private static X509Certificate toCertificate(X509CertificateHolder holder) throws Exception {
        return new JcaX509CertificateConverter().setProvider("BC").getCertificate(holder);
    }

    /** An issued certificate together with the private key that belongs to it. */
    public record IssuedCertificate(String alias, X509Certificate certificate, PrivateKey privateKey) {
    }
}
