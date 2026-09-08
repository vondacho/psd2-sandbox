package ch.obya.psd2.pki;

/**
 * What a certificate is for. The two are distinguishable by their QcType, which is what
 * lets the Bank refuse a QWAC presented as a sealing certificate.
 */
public enum CertificateKind {
    /** Transport: mTLS client authentication. {@code id-etsi-qct-web}, EKU clientAuth. */
    QWAC,
    /** Sealing: request signing. {@code id-etsi-qct-eseal}, keyUsage nonRepudiation, no clientAuth. */
    QSEAL
}
