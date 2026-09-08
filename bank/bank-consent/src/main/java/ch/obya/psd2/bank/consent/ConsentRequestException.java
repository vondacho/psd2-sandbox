package ch.obya.psd2.bank.consent;

/**
 * A request the interface must refuse.
 *
 * <p>Carries the {@code tppMessages} code and either the JSON path or the text the
 * scenarios name, so the REST adapter renders §4.13 without re-deciding anything.
 */
public class ConsentRequestException extends RuntimeException {

    private final String code;
    private final String path;

    public ConsentRequestException(String code, String path, String text) {
        super(text);
        this.code = code;
        this.path = path;
    }

    /** {@code FORMAT_ERROR} for a malformed request. */
    public static ConsentRequestException formatError(String path, String text) {
        return new ConsentRequestException("FORMAT_ERROR", path, text);
    }

    /** {@code CONSENT_UNKNOWN}, answered with 403. */
    public static ConsentRequestException consentUnknown(String consentId) {
        return new ConsentRequestException("CONSENT_UNKNOWN", null,
                "no consent " + consentId + " for this TPP");
    }

    public String code() {
        return code;
    }

    /** The offending field, e.g. {@code validUntil}; null when the fault is not one field. */
    public String path() {
        return path;
    }
}
