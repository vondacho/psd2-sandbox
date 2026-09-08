package ch.obya.psd2.bank.ciam;

import java.security.PublicKey;
import java.time.Instant;

/**
 * One device enrolled for one PSU, holding the public half of a key whose private half
 * never leaves the phone's secure hardware.
 *
 * <p>"An active device's public key is never replaced; a new key is a new device." That
 * invariant is why {@link #publicKey()} has no setter — key rotation goes through
 * enrolment, so the audit trail keeps both.
 */
public final class RegisteredDevice {

    private final String deviceId;
    private final String psuId;
    private final String name;
    private final PublicKey publicKey;
    private final boolean hardwareBacked;
    private final Instant enrolledAt;

    private DeviceStatus status;
    private Instant lastUsedAt;

    public RegisteredDevice(String deviceId, String psuId, String name, PublicKey publicKey,
            boolean hardwareBacked, DeviceStatus status, Instant enrolledAt) {
        this.deviceId = deviceId;
        this.psuId = psuId;
        this.name = name;
        this.publicKey = publicKey;
        this.hardwareBacked = hardwareBacked;
        this.status = status;
        this.enrolledAt = enrolledAt;
    }

    public String deviceId() {
        return deviceId;
    }

    /** "A device belongs to exactly one identity." */
    public String psuId() {
        return psuId;
    }

    public String name() {
        return name;
    }

    public PublicKey publicKey() {
        return publicKey;
    }

    public boolean hardwareBacked() {
        return hardwareBacked;
    }

    public DeviceStatus status() {
        return status;
    }

    public Instant enrolledAt() {
        return enrolledAt;
    }

    public Instant lastUsedAt() {
        return lastUsedAt;
    }

    /** "A blocked or removed device cannot answer a challenge." */
    public boolean mayAnswerChallenges() {
        return status == DeviceStatus.ACTIVE;
    }

    /** "A device becomes active only after the enrolment was confirmed with an existing SCA." */
    public void activate() {
        if (status != DeviceStatus.PENDING) {
            throw new IllegalStateException("only a pending device can be activated");
        }
        status = DeviceStatus.ACTIVE;
    }

    public void block() {
        status = DeviceStatus.BLOCKED;
    }

    public void remove() {
        status = DeviceStatus.REMOVED;
    }

    void recordUse(Instant at) {
        lastUsedAt = at;
    }
}
