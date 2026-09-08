package ch.obya.psd2.bank.tpp.appl;

import ch.obya.psd2.bank.tpp.domain.*;

import ch.obya.psd2.spec.OrganizationIdentifier;
import java.math.BigInteger;
import java.security.MessageDigest;
import java.security.cert.X509Certificate;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import org.bouncycastle.asn1.ASN1ObjectIdentifier;
import org.bouncycastle.asn1.ASN1OctetString;
import org.bouncycastle.asn1.ASN1Primitive;
import org.bouncycastle.asn1.ASN1Sequence;
import org.bouncycastle.asn1.ASN1String;
import org.bouncycastle.asn1.x500.style.BCStyle;
import org.bouncycastle.asn1.x509.Extension;
import org.bouncycastle.asn1.x509.qualified.QCStatement;
import org.bouncycastle.cert.jcajce.JcaX509CertificateHolder;

/**
 * Turns a presented certificate into a {@link TppIdentity} or a refusal.
 *
 * <p>This is the open host service the context map describes: "Every XS2A endpoint and
 * the OIDC-provider's client registry need the same answer; one service is cheaper than
 * three certificate parsers."
 *
 * <p><strong>What this does and does not check.</strong> Chain validation is the TLS
 * layer's job: a certificate that is not chained to the sandbox CA never reaches here,
 * because the handshake fails first with {@code unknown_ca}. What arrives here is
 * cryptographically trusted, so what is left is semantic — is there a PSD2 statement, is
 * the identifier well formed, is the certificate within its validity window, has it been
 * revoked or blocked, does it hold the role this endpoint needs. Those produce
 * {@code 401 CERTIFICATE_*} or {@code ROLE_INVALID} with a {@code tppMessages} body,
 * which is only possible because the connection itself succeeded.
 */
public final class TppIdentification {

    /** {@code id-etsi-psd2-qcStatement}, ETSI TS 119 495. */
    private static final ASN1ObjectIdentifier ID_ETSI_PSD2_QCSTATEMENT =
            new ASN1ObjectIdentifier("0.4.0.19495.2");
    /** {@code id-etsi-qcs-QcType}, ETSI EN 319 412-5. */
    private static final ASN1ObjectIdentifier ID_ETSI_QCS_QCTYPE =
            new ASN1ObjectIdentifier("0.4.0.1862.1.6");
    private static final ASN1ObjectIdentifier ID_ETSI_QCT_ESEAL = ID_ETSI_QCS_QCTYPE.branch("2");

    private final Clock clock;
    private final RevocationSource revocation;
    private final BlockList blockList;

    public TppIdentification(Clock clock, RevocationSource revocation, BlockList blockList) {
        this.clock = clock;
        this.revocation = revocation;
        this.blockList = blockList;
    }

    /** An identification that trusts every serial, for the walking skeleton. */
    public static TppIdentification acceptingAll(Clock clock) {
        return new TppIdentification(clock, serial -> false, serial -> false);
    }

    /**
     * Reads the certificate. Never throws for a bad certificate: a refusal is a value,
     * because three callers need the same answer and all of them must render it.
     */
    public TppIdentity identify(X509Certificate certificate) {
        Instant now = clock.instant();
        CertificateChainDetails chain;
        try {
            chain = readChain(certificate);
        } catch (Exception e) {
            return TppIdentity.refusal(CertificateVerdict.INVALID,
                    "certificate could not be read", null, now);
        }

        QcStatementDetails statement;
        try {
            statement = readQcStatement(certificate);
        } catch (MissingStatement e) {
            return TppIdentity.refusal(
                    CertificateVerdict.INVALID, "PSD2 QcStatement missing", chain, now);
        } catch (MalformedIdentifier e) {
            return TppIdentity.refusal(
                    CertificateVerdict.INVALID, "organizationIdentifier invalid", chain, now);
        } catch (Exception e) {
            return TppIdentity.refusal(
                    CertificateVerdict.INVALID, "PSD2 QcStatement unreadable", chain, now);
        }

        CertificateKind kind = readKind(certificate);
        String legalName = readSubject(certificate, BCStyle.O);
        TppIdentity identified = new TppIdentity(statement.organizationIdentifier(), legalName,
                kind, chain, statement, CertificateVerdict.VALID, null, now);

        // Order matters: a revoked certificate that is also expired answers EXPIRED,
        // because the validity window is the cheaper and more specific fact.
        if (now.isBefore(chain.notBefore())) {
            return refuse(identified, CertificateVerdict.INVALID, "certificate not yet valid");
        }
        if (now.isAfter(chain.notAfter())) {
            return refuse(identified, CertificateVerdict.EXPIRED, "certificate expired");
        }
        if (blockList.isBlocked(chain.serial())) {
            return refuse(identified, CertificateVerdict.BLOCKED, "certificate blocked by the Bank");
        }
        if (revocation.isRevoked(chain.serial())) {
            return refuse(identified, CertificateVerdict.REVOKED, "certificate revoked");
        }
        return identified;
    }

    /**
     * Identifies and then checks the role the endpoint requires, which is the check
     * every XS2A endpoint makes before it looks at a token.
     */
    public TppIdentity identifyFor(X509Certificate certificate, Psd2Role required) {
        TppIdentity identity = identify(certificate);
        if (identity.isIdentified() && !identity.holds(required)) {
            return refuse(identity, CertificateVerdict.ROLE_MISSING,
                    "certificate does not hold " + required.roleName());
        }
        return identity;
    }

    private static TppIdentity refuse(TppIdentity identity, CertificateVerdict verdict,
            String reason) {
        return new TppIdentity(identity.organizationIdentifier(), identity.legalName(),
                identity.kind(), identity.chain(), identity.qcStatement(), verdict, reason,
                identity.identifiedAt());
    }

    // ---- reading the certificate -----------------------------------------------------

    private static CertificateChainDetails readChain(X509Certificate certificate)
            throws Exception {
        List<String> domains = List.of();
        if (certificate.getSubjectAlternativeNames() != null) {
            domains = certificate.getSubjectAlternativeNames().stream()
                    .filter(entry -> Integer.valueOf(2).equals(entry.get(0))) // dNSName
                    .map(entry -> String.valueOf(entry.get(1)))
                    .toList();
        }
        return new CertificateChainDetails(
                certificate.getSubjectX500Principal().getName(),
                certificate.getIssuerX500Principal().getName(),
                serialOf(certificate),
                thumbprintOf(certificate),
                certificate.getNotBefore().toInstant(),
                certificate.getNotAfter().toInstant(),
                domains);
    }

    /** Uppercase hex, no prefix — the form the CRL and the block list use. */
    public static String serialOf(X509Certificate certificate) {
        BigInteger serial = certificate.getSerialNumber();
        return serial.toString(16).toUpperCase(java.util.Locale.ROOT);
    }

    /** The RFC 8705 {@code x5t#S256} thumbprint: base64url, unpadded, of the DER. */
    public static String thumbprintOf(X509Certificate certificate) throws Exception {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(certificate.getEncoded());
        return Base64.getUrlEncoder().withoutPadding().encodeToString(digest);
    }

    private QcStatementDetails readQcStatement(X509Certificate certificate) throws Exception {
        byte[] extension = certificate.getExtensionValue(Extension.qCStatements.getId());
        if (extension == null) {
            throw new MissingStatement();
        }
        ASN1Sequence statements = ASN1Sequence.getInstance(
                ASN1Primitive.fromByteArray(ASN1OctetString.getInstance(extension).getOctets()));

        ASN1Sequence psd2 = null;
        for (var element : statements) {
            QCStatement statement = QCStatement.getInstance(element);
            if (ID_ETSI_PSD2_QCSTATEMENT.equals(statement.getStatementId())) {
                psd2 = ASN1Sequence.getInstance(statement.getStatementInfo());
            }
        }
        if (psd2 == null) {
            throw new MissingStatement();
        }

        Set<Psd2Role> roles = EnumSet.noneOf(Psd2Role.class);
        for (var element : ASN1Sequence.getInstance(psd2.getObjectAt(0))) {
            ASN1Sequence role = ASN1Sequence.getInstance(element);
            Psd2Role.byOid(ASN1ObjectIdentifier.getInstance(role.getObjectAt(0)).getId())
                    .ifPresent(roles::add);
        }
        String ncaName = ((ASN1String) psd2.getObjectAt(1)).getString();
        String ncaId = ((ASN1String) psd2.getObjectAt(2)).getString();

        String raw = readSubject(certificate, BCStyle.ORGANIZATION_IDENTIFIER);
        if (!OrganizationIdentifier.isValid(raw)) {
            throw new MalformedIdentifier();
        }
        return new QcStatementDetails(
                OrganizationIdentifier.parse(raw), ncaName, ncaId, roles);
    }

    private static CertificateKind readKind(X509Certificate certificate) {
        try {
            byte[] extension = certificate.getExtensionValue(Extension.qCStatements.getId());
            if (extension == null) {
                return CertificateKind.QWAC;
            }
            ASN1Sequence statements = ASN1Sequence.getInstance(ASN1Primitive.fromByteArray(
                    ASN1OctetString.getInstance(extension).getOctets()));
            for (var element : statements) {
                QCStatement statement = QCStatement.getInstance(element);
                if (ID_ETSI_QCS_QCTYPE.equals(statement.getStatementId())) {
                    ASN1ObjectIdentifier type = ASN1ObjectIdentifier.getInstance(
                            ASN1Sequence.getInstance(statement.getStatementInfo()).getObjectAt(0));
                    return ID_ETSI_QCT_ESEAL.equals(type)
                            ? CertificateKind.QSEAL : CertificateKind.QWAC;
                }
            }
        } catch (Exception ignored) {
            // A certificate whose QcType cannot be read is treated as a QWAC; the PSD2
            // statement check above has already decided whether it is usable at all.
        }
        return CertificateKind.QWAC;
    }

    private static String readSubject(X509Certificate certificate, ASN1ObjectIdentifier oid) {
        try {
            var rdns = new JcaX509CertificateHolder(certificate).getSubject().getRDNs(oid);
            if (rdns.length == 0) {
                return null;
            }
            return ((ASN1String) rdns[0].getFirst().getValue()).getString();
        } catch (Exception e) {
            return null;
        }
    }

    /** Where revocation is looked up. The CRL of the sandbox CA, in practice. */
    @FunctionalInterface
    public interface RevocationSource {
        boolean isRevoked(String serial);
    }

    /** The Bank's own block list, which is not revocation: the CA still vouches for it. */
    @FunctionalInterface
    public interface BlockList {
        boolean isBlocked(String serial);
    }

    private static final class MissingStatement extends RuntimeException {
    }

    private static final class MalformedIdentifier extends RuntimeException {
    }
}
