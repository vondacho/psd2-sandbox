package ch.obya.psd2.bank.tpp;

import ch.obya.psd2.bank.tpp.domain.*;
import ch.obya.psd2.bank.tpp.appl.*;

import ch.obya.psd2.pki.CertificateKind;
import ch.obya.psd2.pki.IssuanceRequest;
import ch.obya.psd2.pki.PkiFixtures;
import ch.obya.psd2.pki.SandboxCa;
import java.security.cert.X509Certificate;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Covers {@code docs/design/features/2-connect-the-bank-from-the-tpp/
 * validate-the-qwac-and-its-psd2-roles.feature}, driven by the certificates the
 * {@code pki} module issues rather than by hand-rolled fixtures.
 */
class TppIdentificationTest {

    private static final Instant TODAY = PkiFixtures.TODAY;

    private static SandboxCa ca;
    private static X509Certificate tpp;          // AISP + PISP
    private static X509Certificate tppC;         // PISP only
    private static X509Certificate aispOnly;
    private static X509Certificate expired;
    private static X509Certificate notYetValid;
    private static X509Certificate seal;

    private final Set<String> revoked = new HashSet<>();
    private final Set<String> blocked = new HashSet<>();
    private final TppIdentification identification = new TppIdentification(
            Clock.fixed(TODAY.plus(Duration.ofHours(12)), ZoneOffset.UTC),
            revoked::contains, blocked::contains);

    @BeforeAll
    static void issueFixtures() throws Exception {
        ca = SandboxCa.create(TODAY);
        for (IssuanceRequest request : PkiFixtures.identities()) {
            X509Certificate issued = ca.issue(request).certificate();
            switch (request.alias()) {
                case "tpp" -> tpp = issued;
                case "tpp-c" -> tppC = issued;
                case "tpp-aisp-only" -> aispOnly = issued;
                case "tpp-expired" -> expired = issued;
                case "tpp-not-yet-valid" -> notYetValid = issued;
                case "tpp-seal" -> seal = issued;
                default -> { }
            }
        }
    }

    @Test
    @DisplayName("The TPP's QWAC chained to the sandbox CA is accepted")
    void validQwacIsIdentified() {
        TppIdentity identity = identification.identify(tpp);

        assertTrue(identity.isIdentified());
        assertEquals(CertificateVerdict.VALID, identity.verdict());
        assertEquals("PSDDE-BAFIN-123456", identity.organizationIdentifier().value());
        assertEquals("TPP Fintech GmbH", identity.legalName());
        assertEquals(Set.of(Psd2Role.AISP, Psd2Role.PISP), identity.roles());
        assertEquals("BaFin", identity.qcStatement().ncaName());
        assertEquals("DE-BAFIN", identity.qcStatement().ncaId());
        assertEquals(List.of("tpp.sandbox"), identity.chain().domains());
        assertTrue(identity.messageCode().isEmpty());
    }

    @Test
    @DisplayName("A certificate without a PSD2 QcStatement is refused")
    void noStatementIsRefused() throws Exception {
        X509Certificate plain = CertificatesWithoutStatements.issue(ca, TODAY);

        TppIdentity identity = identification.identify(plain);

        assertEquals(CertificateVerdict.INVALID, identity.verdict());
        assertEquals("PSD2 QcStatement missing", identity.reason());
        assertEquals("CERTIFICATE_INVALID", identity.messageCode().orElseThrow());
        assertNull(identity.organizationIdentifier(), "a refusal carries no identity");
    }

    @Test
    @DisplayName("A certificate whose organizationIdentifier is malformed is refused")
    void malformedIdentifierIsRefused() throws Exception {
        X509Certificate acme = ca.issue(new IssuanceRequest("acme", CertificateKind.QWAC,
                Set.of(ch.obya.psd2.pki.Psd2Role.AISP), "Acme Ltd", "ACME-123", "BaFin",
                "DE-BAFIN", List.of("acme.sandbox"), TODAY, IssuanceRequest.DEFAULT_VALIDITY))
                .certificate();

        TppIdentity identity = identification.identify(acme);

        assertEquals(CertificateVerdict.INVALID, identity.verdict());
        assertEquals("organizationIdentifier invalid", identity.reason());
    }

    @Test
    @DisplayName("An expired certificate gets CERTIFICATE_EXPIRED")
    void expiredCertificate() {
        TppIdentity identity = identification.identify(expired);

        assertEquals(CertificateVerdict.EXPIRED, identity.verdict());
        assertEquals("CERTIFICATE_EXPIRED", identity.messageCode().orElseThrow());
    }

    @Test
    @DisplayName("A certificate not yet valid gets CERTIFICATE_INVALID")
    void notYetValidCertificate() {
        TppIdentity identity = identification.identify(notYetValid);

        assertEquals(CertificateVerdict.INVALID, identity.verdict());
        assertEquals("CERTIFICATE_INVALID", identity.messageCode().orElseThrow());
    }

    @Test
    @DisplayName("A revoked certificate gets CERTIFICATE_REVOKED")
    void revokedCertificate() {
        revoked.add(TppIdentification.serialOf(tpp));

        TppIdentity identity = identification.identify(tpp);

        assertEquals(CertificateVerdict.REVOKED, identity.verdict());
        assertEquals("CERTIFICATE_REVOKED", identity.messageCode().orElseThrow());
    }

    @Test
    @DisplayName("A certificate blocked by the Bank gets CERTIFICATE_BLOCKED")
    void blockedCertificate() {
        blocked.add(TppIdentification.serialOf(tpp));

        TppIdentity identity = identification.identify(tpp);

        assertEquals(CertificateVerdict.BLOCKED, identity.verdict());
        assertEquals("CERTIFICATE_BLOCKED", identity.messageCode().orElseThrow());
    }

    @Test
    @DisplayName("A certificate with AISP and PISP may create consents")
    void aispAndPispMayCreateConsents() {
        assertTrue(identification.identifyFor(tpp, Psd2Role.AISP).isIdentified());
    }

    @Test
    @DisplayName("A PISP-only certificate may not create consents")
    void pispOnlyMayNotCreateConsents() {
        TppIdentity identity = identification.identifyFor(tppC, Psd2Role.AISP);

        assertEquals(CertificateVerdict.ROLE_MISSING, identity.verdict());
        assertEquals("ROLE_INVALID", identity.messageCode().orElseThrow());
    }

    @Test
    @DisplayName("An AISP-only certificate may not initiate payments")
    void aispOnlyMayNotPay() {
        assertEquals(CertificateVerdict.ROLE_MISSING,
                identification.identifyFor(aispOnly, Psd2Role.PISP).verdict());
    }

    @Test
    @DisplayName("A PIISP-only certificate may not read accounts")
    void piispOnlyMayNotReadAccounts() throws Exception {
        X509Certificate piisp = ca.issue(new IssuanceRequest("tpp-piisp", CertificateKind.QWAC,
                Set.of(ch.obya.psd2.pki.Psd2Role.PIISP), "Card Co", "PSDDE-BAFIN-777777",
                "BaFin", "DE-BAFIN", List.of("card.sandbox"), TODAY,
                IssuanceRequest.DEFAULT_VALIDITY)).certificate();

        assertEquals(CertificateVerdict.ROLE_MISSING,
                identification.identifyFor(piisp, Psd2Role.AISP).verdict());
        assertEquals(Set.of(Psd2Role.PIISP), identification.identify(piisp).roles());
    }

    @Test
    @DisplayName("The organizationIdentifier is the identity for everything that follows")
    void identifierIsTheTppId() {
        assertEquals("PSDDE-BAFIN-123456",
                identification.identify(tpp).organizationIdentifier().value());
    }

    @Test
    @DisplayName("A renewed certificate with the same organizationIdentifier keeps the identity")
    void renewedCertificateKeepsTheIdentity() throws Exception {
        X509Certificate renewed = ca.issue(new IssuanceRequest("tpp-renewed",
                CertificateKind.QWAC, Set.of(ch.obya.psd2.pki.Psd2Role.AISP,
                        ch.obya.psd2.pki.Psd2Role.PISP), "TPP Fintech GmbH",
                "PSDDE-BAFIN-123456", "BaFin", "DE-BAFIN", List.of("tpp.sandbox"),
                TODAY, IssuanceRequest.DEFAULT_VALIDITY)).certificate();

        assertEquals(identification.identify(tpp).organizationIdentifier(),
                identification.identify(renewed).organizationIdentifier());
        assertFalse(TppIdentification.serialOf(tpp).equals(TppIdentification.serialOf(renewed)),
                "a different certificate, the same identity");
    }

    @Test
    @DisplayName("A QSEAL is told apart from a QWAC by its QcType")
    void sealIsDistinguishable() {
        assertEquals(ch.obya.psd2.bank.tpp.domain.CertificateKind.QSEAL,
                identification.identify(seal).kind());
        assertEquals(ch.obya.psd2.bank.tpp.domain.CertificateKind.QWAC,
                identification.identify(tpp).kind());
    }

    @Test
    @DisplayName("A sealing certificate identifies the same TPP as the transport certificate")
    void sealAndQwacAgreeOnTheTpp() {
        assertEquals(identification.identify(tpp).organizationIdentifier(),
                identification.identify(seal).organizationIdentifier());
    }

    @Test
    @DisplayName("The thumbprint is the RFC 8705 x5t#S256 the token will be bound to")
    void thumbprintIsBase64UrlUnpadded() throws Exception {
        String thumbprint = TppIdentification.thumbprintOf(tpp);

        assertEquals(43, thumbprint.length(), "SHA-256, base64url, unpadded");
        assertFalse(thumbprint.contains("=") || thumbprint.contains("+")
                || thumbprint.contains("/"), "must be base64url without padding");
    }
}
