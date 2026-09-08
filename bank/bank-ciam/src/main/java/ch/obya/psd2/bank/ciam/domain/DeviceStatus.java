package ch.obya.psd2.bank.ciam.domain;

/** The lifecycle of an enrolled device. Only {@code ACTIVE} may answer a challenge. */
public enum DeviceStatus {
    PENDING, ACTIVE, BLOCKED, REMOVED
}
