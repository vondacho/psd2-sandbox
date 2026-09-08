package ch.obya.psd2.pki;

import java.io.IOException;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.cert.X509CRL;
import java.security.cert.X509Certificate;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Set;
import org.bouncycastle.util.io.pem.PemObject;
import org.bouncycastle.util.io.pem.PemWriter;

/**
 * Generates the whole sandbox PKI in one pass, as a build-time fixture rather than a
 * running service.
 *
 * <p>Seven identities are issued up front because the error scenarios need several at
 * once — {@code validate-token-and-consent-on-every-call.feature} and
 * {@code terminate-the-xs2a-tls-with-a-client-certificate.feature} each pull more than
 * one. Generating per scenario would mean a P-256 keygen plus ASN.1 encoding per
 * scenario, which is too slow for a 521-scenario suite.
 */
public final class PkiFixtures {

    /** "Today" of the shared fixtures: 2026-09-06, the Bank's zone. */
    public static final Instant TODAY =
            LocalDate.of(2026, 9, 6).atStartOfDay(ZoneOffset.UTC).toInstant();

    /** The passphrase of the generated keystores. It is a sandbox; there is no secret here. */
    public static final char[] KEYSTORE_PASSWORD = "sandbox".toCharArray();

    private PkiFixtures() {
    }

    /**
     * Writes the CA, the seven identities and a CRL under {@code outputDirectory}.
     *
     * @return the CA that issued them, so a caller can revoke and re-publish
     */
    public static SandboxCa generateInto(Path outputDirectory) throws Exception {
        Files.createDirectories(outputDirectory);
        SandboxCa ca = SandboxCa.create(TODAY);
        writePem(outputDirectory.resolve("ca.pem"), "CERTIFICATE", ca.certificate().getEncoded());
        writeTrustStore(outputDirectory.resolve("truststore.p12"), ca.certificate());

        for (IssuanceRequest request : identities()) {
            SandboxCa.IssuedCertificate issued = ca.issue(request);
            write(outputDirectory, issued, ca.certificate());
        }

        // The 'revoked' identity is issued and then revoked, so the CRL has an entry from
        // the first build. 401 CERTIFICATE_REVOKED needs a certificate that once existed.
        ca.revoke("tpp-revoked", TODAY);
        writeCrl(outputDirectory.resolve("crl.pem"), ca.crl(TODAY));
        return ca;
    }

    /**
     * The seven fixtures, named as the acceptance suite refers to them. Values follow
     * {@code docs/design/examplemap/README.md}.
     */
    public static List<IssuanceRequest> identities() {
        return List.of(
                // The TPP of the journey: AISP and PISP, valid, tpp.sandbox.
                identity("tpp", CertificateKind.QWAC, Set.of(Psd2Role.AISP, Psd2Role.PISP),
                        "TPP Fintech GmbH", "PSDDE-BAFIN-123456", "tpp.sandbox",
                        TODAY, IssuanceRequest.DEFAULT_VALIDITY),
                // TPP C: PISP only, used to prove role and ownership checks.
                identity("tpp-c", CertificateKind.QWAC, Set.of(Psd2Role.PISP),
                        "C Pay", "PSDDE-BAFIN-654321", "tpp-c.sandbox",
                        TODAY, IssuanceRequest.DEFAULT_VALIDITY),
                // AISP only: refused on payment endpoints, which need PISP.
                identity("tpp-aisp-only", CertificateKind.QWAC, Set.of(Psd2Role.AISP),
                        "TPP Fintech GmbH", "PSDDE-BAFIN-123456", "tpp.sandbox",
                        TODAY, IssuanceRequest.DEFAULT_VALIDITY),
                // Expired a day ago: 401 CERTIFICATE_EXPIRED.
                identity("tpp-expired", CertificateKind.QWAC, Set.of(Psd2Role.AISP, Psd2Role.PISP),
                        "TPP Fintech GmbH", "PSDDE-BAFIN-123456", "tpp.sandbox",
                        TODAY.minus(Duration.ofDays(366)), IssuanceRequest.DEFAULT_VALIDITY),
                // Not valid until tomorrow: 401 CERTIFICATE_INVALID.
                identity("tpp-not-yet-valid", CertificateKind.QWAC, Set.of(Psd2Role.AISP),
                        "TPP Fintech GmbH", "PSDDE-BAFIN-123456", "tpp.sandbox",
                        TODAY.plus(Duration.ofDays(1)), IssuanceRequest.DEFAULT_VALIDITY),
                // Issued then revoked below: 401 CERTIFICATE_REVOKED.
                identity("tpp-revoked", CertificateKind.QWAC, Set.of(Psd2Role.AISP, Psd2Role.PISP),
                        "TPP Fintech GmbH", "PSDDE-BAFIN-123456", "tpp.sandbox",
                        TODAY, IssuanceRequest.DEFAULT_VALIDITY),
                // The sealing certificate, for QSEAL request signing (@hardening).
                identity("tpp-seal", CertificateKind.QSEAL, Set.of(Psd2Role.AISP, Psd2Role.PISP),
                        "TPP Fintech GmbH", "PSDDE-BAFIN-123456", null,
                        TODAY, IssuanceRequest.DEFAULT_VALIDITY));
    }

    private static IssuanceRequest identity(String alias, CertificateKind kind,
            Set<Psd2Role> roles, String organizationName, String organizationIdentifier,
            String dnsName, Instant notBefore, Duration validity) {
        return new IssuanceRequest(alias, kind, roles, organizationName, organizationIdentifier,
                "BaFin", "DE-BAFIN", dnsName == null ? List.of() : List.of(dnsName),
                notBefore, validity);
    }

    private static void write(Path directory, SandboxCa.IssuedCertificate issued,
            X509Certificate ca) throws Exception {
        writePem(directory.resolve(issued.alias() + ".pem"), "CERTIFICATE",
                issued.certificate().getEncoded());
        writePem(directory.resolve(issued.alias() + ".key"), "PRIVATE KEY",
                issued.privateKey().getEncoded());
        writeKeyStore(directory.resolve(issued.alias() + ".p12"), issued.alias(),
                issued.privateKey(), issued.certificate(), ca);
    }

    private static void writeKeyStore(Path path, String alias, PrivateKey key,
            X509Certificate certificate, X509Certificate ca) throws Exception {
        KeyStore store = KeyStore.getInstance("PKCS12");
        store.load(null, null);
        store.setKeyEntry(alias, key, KEYSTORE_PASSWORD,
                new java.security.cert.Certificate[] {certificate, ca});
        try (var out = Files.newOutputStream(path)) {
            store.store(out, KEYSTORE_PASSWORD);
        }
    }

    private static void writeTrustStore(Path path, X509Certificate ca) throws Exception {
        KeyStore store = KeyStore.getInstance("PKCS12");
        store.load(null, null);
        store.setCertificateEntry("sandbox-ca", ca);
        try (var out = Files.newOutputStream(path)) {
            store.store(out, KEYSTORE_PASSWORD);
        }
    }

    private static void writeCrl(Path path, X509CRL crl) throws Exception {
        writePem(path, "X509 CRL", crl.getEncoded());
    }

    private static void writePem(Path path, String type, byte[] der) throws IOException {
        StringWriter text = new StringWriter();
        try (PemWriter writer = new PemWriter(text)) {
            writer.writeObject(new PemObject(type, der));
        }
        Files.writeString(path, text.toString(), StandardCharsets.UTF_8);
    }
}
