package ch.obya.psd2.bank.ciam.domain;

/** A challenge is answered at most once, so every status but {@code PENDING} is final. */
public enum ChallengeStatus {
    PENDING, APPROVED, DENIED, EXPIRED;

    public boolean isFinal() {
        return this != PENDING;
    }
}
