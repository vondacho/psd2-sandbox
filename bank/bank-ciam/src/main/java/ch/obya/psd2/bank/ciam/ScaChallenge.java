package ch.obya.psd2.bank.ciam;

import java.nio.charset.StandardCharsets;
import java.security.PublicKey;
import java.security.SecureRandom;
import java.security.Signature;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;

/**
 * One SCA challenge: what the PSU is asked to approve on a registered device, and the
 * proof that they did.
 *
 * <p>Three rules do the security work here, and each is a method rather than a caller's
 * responsibility, because a caller that forgets one is a vulnerability:
 *
 * <ul>
 *   <li>it expires three minutes after creation;
 *   <li>it is answered at most once, whatever the answer;
 *   <li>a signature counts only if it verifies against the key stored at enrolment, over
 *       this challenge's own message — never a key supplied in the response.
 * </ul>
 */
public final class ScaChallenge {

    /** EBA RTS art. 4: the challenge is short-lived. */
    public static final Duration LIFETIME = Duration.ofMinutes(3);

    private static final SecureRandom RANDOM = new SecureRandom();

    private final String challengeId;
    private final String psuId;
    private final ChallengeSubjectKind subjectKind;
    private final String subjectId;
    private final String nonce;
    private final DynamicLink dynamicLink;
    private final Instant createdAt;
    private final Instant expiresAt;

    private ChallengeStatus status = ChallengeStatus.PENDING;
    private String answeredByDeviceId;
    private String signature;
    private Instant answeredAt;

    ScaChallenge(String challengeId, String psuId, ChallengeSubjectKind subjectKind,
            String subjectId, DynamicLink dynamicLink, Instant createdAt) {
        this.challengeId = challengeId;
        this.psuId = psuId;
        this.subjectKind = subjectKind;
        this.subjectId = subjectId;
        this.dynamicLink = dynamicLink;
        this.createdAt = createdAt;
        this.expiresAt = createdAt.plus(LIFETIME);
        this.nonce = newNonce();
    }

    /** 128 bits, base64url without padding — 22 characters. */
    private static String newNonce() {
        byte[] bytes = new byte[16];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public String challengeId() {
        return challengeId;
    }

    public String psuId() {
        return psuId;
    }

    public ChallengeSubjectKind subjectKind() {
        return subjectKind;
    }

    public String subjectId() {
        return subjectId;
    }

    public String nonce() {
        return nonce;
    }

    public DynamicLink dynamicLink() {
        return dynamicLink;
    }

    public Instant createdAt() {
        return createdAt;
    }

    public Instant expiresAt() {
        return expiresAt;
    }

    public ChallengeStatus status() {
        return status;
    }

    public String answeredByDeviceId() {
        return answeredByDeviceId;
    }

    public String signature() {
        return signature;
    }

    public Instant answeredAt() {
        return answeredAt;
    }

    /**
     * What the device signs: {@code challengeId|nonce|dynamicLinkHash}.
     *
     * <p>The nonce stops a signature being replayed onto another challenge, and the hash
     * is what ties the signature to the amount, the accounts and the validity the PSU
     * actually saw — dynamic linking in one string.
     */
    public String messageToSign() {
        return challengeId + "|" + nonce + "|" + dynamicLink.hash();
    }

    public boolean isExpired(Instant now) {
        return !now.isBefore(expiresAt);
    }

    /** The QR payload the PSU scans, and the deep link an app-to-app redirect uses. */
    public String qrPayload(String endpoint) {
        return endpoint + "/" + challengeId + "#" + nonce;
    }

    /**
     * Verifies a device's answer and, if it holds, approves the challenge.
     *
     * @param device the device the response names; its stored key is the only one used
     * @param signatureBase64 base64url ECDSA signature over {@link #messageToSign()}
     * @return why it was refused, or {@link Outcome#APPROVED}
     */
    public Outcome answer(RegisteredDevice device, String signatureBase64, Instant now) {
        if (status.isFinal()) {
            // "A second correct signature" must not re-approve, and must not un-approve.
            return Outcome.ALREADY_ANSWERED;
        }
        if (isExpired(now)) {
            status = ChallengeStatus.EXPIRED;
            return Outcome.EXPIRED;
        }
        if (device == null) {
            return Outcome.UNKNOWN_DEVICE;
        }
        if (!device.mayAnswerChallenges()) {
            return Outcome.DEVICE_NOT_ACTIVE;
        }
        if (!device.psuId().equals(psuId)) {
            // Ben's device, however active, cannot approve for Anna.
            return Outcome.DEVICE_OF_ANOTHER_PSU;
        }
        if (!verifies(device.publicKey(), signatureBase64)) {
            return Outcome.BAD_SIGNATURE;
        }
        status = ChallengeStatus.APPROVED;
        answeredByDeviceId = device.deviceId();
        signature = signatureBase64;
        answeredAt = now;
        device.recordUse(now);
        return Outcome.APPROVED;
    }

    /** The PSU pressed "deny" on the device. */
    public void deny(Instant now) {
        if (status.isFinal()) {
            return;
        }
        status = ChallengeStatus.DENIED;
        answeredAt = now;
    }

    /** Superseded by a newer challenge in the same session, or timed out. */
    void expire() {
        if (!status.isFinal()) {
            status = ChallengeStatus.EXPIRED;
        }
    }

    private boolean verifies(PublicKey key, String signatureBase64) {
        try {
            Signature ecdsa = Signature.getInstance("SHA256withECDSA");
            ecdsa.initVerify(key);
            ecdsa.update(messageToSign().getBytes(StandardCharsets.UTF_8));
            return ecdsa.verify(Base64.getUrlDecoder().decode(signatureBase64));
        } catch (Exception malformedOrWrongKey) {
            // Random bytes, a signature over another message, a signature by another
            // key: all land here, and all mean the same thing to the caller.
            return false;
        }
    }

    /** Why a response was not accepted. Distinct values so the CIAM can log precisely. */
    public enum Outcome {
        APPROVED,
        EXPIRED,
        ALREADY_ANSWERED,
        UNKNOWN_DEVICE,
        DEVICE_NOT_ACTIVE,
        DEVICE_OF_ANOTHER_PSU,
        BAD_SIGNATURE;

        public boolean isApproved() {
            return this == APPROVED;
        }
    }
}
