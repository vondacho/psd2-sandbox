package ch.obya.psd2.bank.tpp;

/**
 * The outcome of identifying a certificate. The six values of
 * {@code tpp-identification.ddm}, each mapping to the message code the interface returns.
 */
public enum CertificateVerdict {

    VALID(null),
    INVALID("CERTIFICATE_INVALID"),
    EXPIRED("CERTIFICATE_EXPIRED"),
    REVOKED("CERTIFICATE_REVOKED"),
    BLOCKED("CERTIFICATE_BLOCKED"),
    /** The certificate is sound but lacks the role the endpoint requires. */
    ROLE_MISSING("ROLE_INVALID");

    private final String messageCode;

    CertificateVerdict(String messageCode) {
        this.messageCode = messageCode;
    }

    /** The {@code tppMessages} code, or null when the verdict is {@link #VALID}. */
    public String messageCode() {
        return messageCode;
    }

    public boolean isRefusal() {
        return this != VALID;
    }
}
