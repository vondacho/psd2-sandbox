package ch.obya.psd2.pki;

import java.util.Collection;
import org.bouncycastle.asn1.ASN1EncodableVector;
import org.bouncycastle.asn1.ASN1ObjectIdentifier;
import org.bouncycastle.asn1.ASN1Sequence;
import org.bouncycastle.asn1.DERSequence;
import org.bouncycastle.asn1.DERUTF8String;
import org.bouncycastle.asn1.x509.qualified.QCStatement;

/**
 * The ETSI TS 119 495 PSD2 QcStatement, built by hand because no library ships it.
 *
 * <pre>
 * PSD2QcType ::= SEQUENCE {
 *     rolesOfPSP  RolesOfPSP,
 *     nCAName     NCAName,
 *     nCAId       NCAId }
 *
 * RolesOfPSP  ::= SEQUENCE OF RoleOfPSP
 * RoleOfPSP   ::= SEQUENCE {
 *     roleOfPspOid   RoleOfPspOid,       -- 0.4.0.19495.1.{1..4}
 *     roleOfPspName  RoleOfPspName }     -- UTF8String, e.g. "PSP_AI"
 * NCAName     ::= UTF8String             -- e.g. "BaFin"
 * NCAId       ::= UTF8String             -- e.g. "DE-BAFIN"
 * </pre>
 *
 * <p>The statement is carried inside the {@code qcStatements} extension
 * (OID {@code 1.3.6.1.5.5.7.1.3}) under statement id {@code 0.4.0.19495.2}.
 */
public final class Psd2QcStatement {

    /** {@code id-etsi-psd2-qcStatement}: the statement id the Bank looks for. */
    public static final ASN1ObjectIdentifier ID_ETSI_PSD2_QCSTATEMENT =
            new ASN1ObjectIdentifier("0.4.0.19495.2");

    /** {@code id-etsi-qcs-QcType}, ETSI EN 319 412-5. */
    public static final ASN1ObjectIdentifier ID_ETSI_QCS_QCTYPE =
            new ASN1ObjectIdentifier("0.4.0.1862.1.6");

    /** {@code id-etsi-qct-eseal}: a QSEAL, for sealing/request signing. */
    public static final ASN1ObjectIdentifier ID_ETSI_QCT_ESEAL = ID_ETSI_QCS_QCTYPE.branch("2");

    /** {@code id-etsi-qct-web}: a QWAC, for website/transport authentication. */
    public static final ASN1ObjectIdentifier ID_ETSI_QCT_WEB = ID_ETSI_QCS_QCTYPE.branch("3");

    private Psd2QcStatement() {
    }

    /**
     * The PSD2 statement itself: the roles, the competent authority's name and its id.
     *
     * @param roles at least one; encoded in the declaration order of {@link Psd2Role} so
     *     two certificates with the same roles encode identically
     * @param ncaName e.g. {@code BaFin}
     * @param ncaId e.g. {@code DE-BAFIN}
     */
    public static QCStatement psd2(Collection<Psd2Role> roles, String ncaName, String ncaId) {
        if (roles.isEmpty()) {
            throw new IllegalArgumentException("at least one PSD2 role is required");
        }
        ASN1EncodableVector rolesOfPsp = new ASN1EncodableVector();
        for (Psd2Role role : Psd2Role.values()) {
            if (roles.contains(role)) {
                rolesOfPsp.add(new DERSequence(new org.bouncycastle.asn1.ASN1Encodable[] {
                        role.oid(), new DERUTF8String(role.roleName())
                }));
            }
        }
        ASN1Sequence psd2 = new DERSequence(new org.bouncycastle.asn1.ASN1Encodable[] {
                new DERSequence(rolesOfPsp),
                new DERUTF8String(ncaName),
                new DERUTF8String(ncaId)
        });
        return new QCStatement(ID_ETSI_PSD2_QCSTATEMENT, psd2);
    }

    /**
     * The QcType statement that separates a QWAC from a QSEAL. The Bank refuses a QWAC
     * offered as a sealing certificate by reading exactly this.
     */
    public static QCStatement qcType(CertificateKind kind) {
        ASN1ObjectIdentifier type =
                kind == CertificateKind.QSEAL ? ID_ETSI_QCT_ESEAL : ID_ETSI_QCT_WEB;
        return new QCStatement(ID_ETSI_QCS_QCTYPE, new DERSequence(type));
    }
}
