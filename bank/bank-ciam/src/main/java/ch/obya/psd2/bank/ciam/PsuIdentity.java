package ch.obya.psd2.bank.ciam;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;

/**
 * A customer of the Bank: credentials, and the devices that may approve on their behalf.
 *
 * <p>"A locked or closed identity cannot start an authentication session", and the
 * credential "is locked after the configured number of failed tries" — five.
 */
public final class PsuIdentity {

    /** "A failed login says only that the credentials are invalid" — after five, locked. */
    public static final int MAX_FAILED_TRIES = 5;

    private final String psuId;
    private final String displayName;
    private final String secretHash;

    private Status status = Status.ACTIVE;
    private int failedTries;

    public PsuIdentity(String psuId, String displayName, String password) {
        this.psuId = psuId;
        this.displayName = displayName;
        this.secretHash = hash(password);
    }

    public String psuId() {
        return psuId;
    }

    public String displayName() {
        return displayName;
    }

    public Status status() {
        return status;
    }

    public int failedTries() {
        return failedTries;
    }

    /** "A locked or closed identity cannot start an authentication session." */
    public boolean canAuthenticate() {
        return status == Status.ACTIVE;
    }

    /**
     * Verifies the first factor.
     *
     * <p>Returns a boolean rather than throwing, and the caller is expected to answer the
     * same way for a wrong password, an unknown PSU and a locked identity: "a failed login
     * says only that the credentials are invalid".
     */
    public boolean verifyPassword(String candidate) {
        if (!canAuthenticate()) {
            return false;
        }
        if (MessageDigest.isEqual(secretHash.getBytes(StandardCharsets.UTF_8),
                hash(candidate).getBytes(StandardCharsets.UTF_8))) {
            failedTries = 0;
            return true;
        }
        failedTries++;
        if (failedTries >= MAX_FAILED_TRIES) {
            status = Status.LOCKED;
        }
        return false;
    }

    public void lock() {
        status = Status.LOCKED;
    }

    public void close() {
        status = Status.CLOSED;
    }

    private static String hash(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 is required", e);
        }
    }

    /** A sandbox stores a hash, not a password; a real CIAM would use a KDF. */
    public enum Status {
        ACTIVE, LOCKED, CLOSED
    }
}
