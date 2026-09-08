package ch.obya.psd2.pki;

import java.security.cert.X509CRL;
import java.security.cert.X509Certificate;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Set;
import org.bouncycastle.asn1.ASN1ObjectIdentifier;
import org.bouncycastle.asn1.ASN1Primitive;
import org.bouncycastle.asn1.ASN1Sequence;
import org.bouncycastle.asn1.ASN1String;
import org.bouncycastle.asn1.x500.style.BCStyle;
import org.bouncycastle.asn1.x509.Extension;
import org.bouncycastle.asn1.x509.qualified.QCStatement;
import org.bouncycastle.cert.jcajce.JcaX509CertificateHolder;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Covers {@code docs/design/features/2-connect-the-bank-from-the-tpp/
 * issue-test-qwacs-from-a-sandbox-ca.feature}. Scenario names are quoted in the
 * {@code @DisplayName}s so the two can be read side by side.
 *
 * <p>Fixture values are those of {@code docs/design/examplemap/README.md}: today is
 * 2026-09-06, the TPP is "TPP Fintech GmbH" with organizationIdentifier
 * {@code PSDDE-BAFIN-123456} in the domain {@code tpp.sandbox}.
 */
class SandboxCaTest {

    /** "Today" of the shared fixtures: 2026-09-06, Europe/Berlin. */
    private static final Instant TODAY =
            LocalDate.of(2026, 9, 6).atStartOfDay(ZoneOffset.UTC).toInstant();

    private static SandboxCa ca;

    @BeforeAll
    static void createCa() throws Exception {
        ca = SandboxCa.create(TODAY);
    }

    private static IssuanceRequest tppRequest(CertificateKind kind, Set<Psd2Role> roles) {
        return new IssuanceRequest("tpp", kind, roles, "TPP Fintech GmbH",
                "PSDDE-BAFIN-123456", "BaFin", "DE-BAFIN", List.of("tpp.sandbox"),
                TODAY, IssuanceRequest.DEFAULT_VALIDITY);
    }

    @Test
    @DisplayName("A QWAC for the TPP with AISP and PISP")
    void qwacCarriesSubjectRolesSanAndClientAuth() throws Exception {
        X509Certificate cert = ca.issue(
                tppRequest(CertificateKind.QWAC, Set.of(Psd2Role.AISP, Psd2Role.PISP)))
                .certificate();
        var holder = new JcaX509CertificateHolder(cert);

        // "the subject has organizationIdentifier PSDDE-BAFIN-123456 and O 'TPP Fintech GmbH'"
        assertEquals("PSDDE-BAFIN-123456", rdn(holder, BCStyle.ORGANIZATION_IDENTIFIER));
        assertEquals("TPP Fintech GmbH", rdn(holder, BCStyle.O));

        // "the qcStatements extension has id-etsi-psd2-qcStatement with roles PSP_AI and
        //  PSP_PI, NCA name 'BaFin' and NCA id 'DE-BAFIN'"
        ASN1Sequence psd2 = psd2Statement(cert);
        assertEquals(Set.of("PSP_AI", "PSP_PI"), roleNamesOf(psd2));
        assertEquals("BaFin", ((ASN1String) psd2.getObjectAt(1)).getString());
        assertEquals("DE-BAFIN", ((ASN1String) psd2.getObjectAt(2)).getString());

        // "the SAN contains dNSName tpp.sandbox"
        assertTrue(cert.getSubjectAlternativeNames().stream()
                        .anyMatch(entry -> "tpp.sandbox".equals(entry.get(1))),
                "SAN should carry dNSName tpp.sandbox");

        // "extended key usage contains clientAuth"
        assertTrue(cert.getExtendedKeyUsage().contains("1.3.6.1.5.5.7.3.2"));
    }

    @Test
    @DisplayName("A PISP-only QWAC for C")
    void pispOnlyListsOneRole() throws Exception {
        X509Certificate cert = ca.issue(new IssuanceRequest("tpp-c", CertificateKind.QWAC,
                Set.of(Psd2Role.PISP), "C Pay", "PSDDE-BAFIN-654321", "BaFin", "DE-BAFIN",
                List.of("tpp-c.sandbox"), TODAY, IssuanceRequest.DEFAULT_VALIDITY))
                .certificate();

        assertEquals(Set.of("PSP_PI"), roleNamesOf(psd2Statement(cert)));
    }

    @Test
    @DisplayName("A request without any role is refused")
    void noRoleIsRefused() {
        assertEquals("at least one PSD2 role is required",
                assertThrows(IllegalArgumentException.class, () -> Psd2Role.parse("none"))
                        .getMessage());
    }

    @Test
    @DisplayName("A request with an unknown role is refused")
    void unknownRoleIsRefused() {
        assertEquals("unknown role BANK",
                assertThrows(IllegalArgumentException.class, () -> Psd2Role.parse("AISP BANK"))
                        .getMessage());
    }

    @Test
    @DisplayName("openssl shows the QcStatement — the OID 0.4.0.19495.2 is present")
    void statementIdIsTheEtsiPsd2Oid() throws Exception {
        X509Certificate cert =
                ca.issue(tppRequest(CertificateKind.QWAC, Set.of(Psd2Role.AISP))).certificate();

        assertNotNull(cert.getExtensionValue(Extension.qCStatements.getId()),
                "the qcStatements extension must be present");
        assertNotNull(psd2Statement(cert), "0.4.0.19495.2 must be one of the statements");
    }

    @Test
    @DisplayName("A QSEAL for the TPP — eseal QcType, nonRepudiation, no clientAuth")
    void qsealIsDistinguishableFromAQwac() throws Exception {
        X509Certificate seal =
                ca.issue(new IssuanceRequest("tpp-seal", CertificateKind.QSEAL,
                        Set.of(Psd2Role.AISP, Psd2Role.PISP), "TPP Fintech GmbH",
                        "PSDDE-BAFIN-123456", "BaFin", "DE-BAFIN", List.of(),
                        TODAY, IssuanceRequest.DEFAULT_VALIDITY)).certificate();

        assertEquals(Psd2QcStatement.ID_ETSI_QCT_ESEAL, qcType(seal));
        assertTrue(seal.getKeyUsage()[1], "nonRepudiation must be set");
        assertTrue(seal.getExtendedKeyUsage() == null
                        || !seal.getExtendedKeyUsage().contains("1.3.6.1.5.5.7.3.2"),
                "a QSEAL must not carry clientAuth");
    }

    @Test
    @DisplayName("A QWAC presented as a sealing certificate is distinguishable")
    void qwacCarriesTheWebQcType() throws Exception {
        X509Certificate qwac =
                ca.issue(tppRequest(CertificateKind.QWAC, Set.of(Psd2Role.AISP))).certificate();

        assertEquals(Psd2QcStatement.ID_ETSI_QCT_WEB, qcType(qwac));
        assertFalse(Psd2QcStatement.ID_ETSI_QCT_ESEAL.equals(qcType(qwac)),
                "the Bank refuses this as a QSEAL by reading the QcType");
    }

    @Test
    @DisplayName("The default validity is 365 days — issued 2026-09-06, notAfter 2027-09-06")
    void defaultValidityIsOneYear() throws Exception {
        X509Certificate cert =
                ca.issue(tppRequest(CertificateKind.QWAC, Set.of(Psd2Role.AISP))).certificate();

        assertEquals(LocalDate.of(2027, 9, 6),
                cert.getNotAfter().toInstant().atZone(ZoneOffset.UTC).toLocalDate());
    }

    @Test
    @DisplayName("A one-minute certificate expires for the test")
    void shortValidityIsHonoured() throws Exception {
        X509Certificate cert = ca.issue(new IssuanceRequest("tpp-short", CertificateKind.QWAC,
                Set.of(Psd2Role.AISP), "TPP Fintech GmbH", "PSDDE-BAFIN-123456", "BaFin",
                "DE-BAFIN", List.of("tpp.sandbox"), TODAY, Duration.ofMinutes(1)))
                .certificate();

        assertEquals(TODAY.plus(Duration.ofMinutes(1)).getEpochSecond(),
                cert.getNotAfter().toInstant().getEpochSecond());
        assertThrows(java.security.cert.CertificateExpiredException.class,
                () -> cert.checkValidity(java.util.Date.from(TODAY.plus(Duration.ofMinutes(2)))));
    }

    @Test
    @DisplayName("A certificate with notBefore in the future can be issued")
    void futureNotBeforeIsNotYetValid() throws Exception {
        X509Certificate cert = ca.issue(new IssuanceRequest("tpp-future", CertificateKind.QWAC,
                Set.of(Psd2Role.AISP), "TPP Fintech GmbH", "PSDDE-BAFIN-123456", "BaFin",
                "DE-BAFIN", List.of("tpp.sandbox"), TODAY.plus(Duration.ofDays(1)),
                IssuanceRequest.DEFAULT_VALIDITY)).certificate();

        assertThrows(java.security.cert.CertificateNotYetValidException.class,
                () -> cert.checkValidity(java.util.Date.from(TODAY)));
    }

    @Test
    @DisplayName("Revoking the TPP's certificate puts its serial on the CRL")
    void revocationListsTheSerial() throws Exception {
        SandboxCa own = SandboxCa.create(TODAY);
        X509Certificate cert =
                own.issue(tppRequest(CertificateKind.QWAC, Set.of(Psd2Role.AISP))).certificate();
        assertEquals("1a2b", cert.getSerialNumber().toString(16),
                "the first issued serial is the 0x1A2B of the fixtures");

        own.revoke("tpp", TODAY);

        assertNotNull(own.crl(TODAY).getRevokedCertificate(cert.getSerialNumber()));
    }

    @Test
    @DisplayName("The CRL is signed by the CA and has a nextUpdate at most 24 hours ahead")
    void crlIsSignedAndBounded() throws Exception {
        X509CRL crl = ca.crl(TODAY);

        crl.verify(ca.certificate().getPublicKey()); // throws if the signature is wrong
        assertEquals(TODAY.plus(Duration.ofHours(24)).getEpochSecond(),
                crl.getNextUpdate().toInstant().getEpochSecond());
    }

    @Test
    @DisplayName("Revoking an unknown certificate fails")
    void revokingAnUnknownAliasFails() {
        assertEquals("no certificate for tpp-z",
                assertThrows(IllegalArgumentException.class, () -> ca.revoke("tpp-z", TODAY))
                        .getMessage());
    }

    @Test
    @DisplayName("A certificate from a second, unrelated CA is not trusted")
    void anotherCaIsNotTheSandboxCa() throws Exception {
        SandboxCa other = SandboxCa.create(TODAY);
        X509Certificate foreign =
                other.issue(tppRequest(CertificateKind.QWAC, Set.of(Psd2Role.AISP))).certificate();

        assertThrows(java.security.SignatureException.class,
                () -> foreign.verify(ca.certificate().getPublicKey()),
                "the gateway trusts pki/ca.pem and nothing else");
    }

    // ---- reading the ASN.1 back ------------------------------------------------------

    private static String rdn(JcaX509CertificateHolder holder, ASN1ObjectIdentifier oid) {
        return ((ASN1String) holder.getSubject().getRDNs(oid)[0].getFirst().getValue()).getString();
    }

    private static ASN1Sequence statements(X509Certificate cert) throws Exception {
        byte[] value = cert.getExtensionValue(Extension.qCStatements.getId());
        return ASN1Sequence.getInstance(
                ASN1Primitive.fromByteArray(
                        org.bouncycastle.asn1.ASN1OctetString.getInstance(value).getOctets()));
    }

    /** The {@code PSD2QcType} body of statement {@code 0.4.0.19495.2}. */
    private static ASN1Sequence psd2Statement(X509Certificate cert) throws Exception {
        for (var element : statements(cert)) {
            QCStatement statement = QCStatement.getInstance(element);
            if (Psd2QcStatement.ID_ETSI_PSD2_QCSTATEMENT.equals(statement.getStatementId())) {
                return ASN1Sequence.getInstance(statement.getStatementInfo());
            }
        }
        return null;
    }

    private static ASN1ObjectIdentifier qcType(X509Certificate cert) throws Exception {
        for (var element : statements(cert)) {
            QCStatement statement = QCStatement.getInstance(element);
            if (Psd2QcStatement.ID_ETSI_QCS_QCTYPE.equals(statement.getStatementId())) {
                return ASN1ObjectIdentifier.getInstance(
                        ASN1Sequence.getInstance(statement.getStatementInfo()).getObjectAt(0));
            }
        }
        return null;
    }

    private static Set<String> roleNamesOf(ASN1Sequence psd2) {
        ASN1Sequence rolesOfPsp = ASN1Sequence.getInstance(psd2.getObjectAt(0));
        return java.util.stream.StreamSupport.stream(rolesOfPsp.spliterator(), false)
                .map(ASN1Sequence::getInstance)
                .map(role -> ((ASN1String) role.getObjectAt(1)).getString())
                .collect(java.util.stream.Collectors.toSet());
    }
}
