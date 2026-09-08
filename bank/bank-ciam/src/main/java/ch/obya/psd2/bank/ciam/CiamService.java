package ch.obya.psd2.bank.ciam;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Supplier;

/**
 * The CIAM's journey engine: login, account selection, challenge, approval.
 *
 * <p>Every rule that matters lives in the aggregates; this coordinates them and keeps the
 * one invariant that spans several — only one challenge is pending per session, so a
 * second one supersedes the first rather than running beside it.
 */
public final class CiamService {

    private final Clock clock;
    private final Supplier<String> challengeIds;
    private final Map<String, PsuIdentity> identities = new ConcurrentHashMap<>();
    private final Map<String, RegisteredDevice> devices = new ConcurrentHashMap<>();
    private final Map<String, ScaChallenge> challenges = new ConcurrentHashMap<>();
    private final Map<String, AuthenticationSession> sessions = new ConcurrentHashMap<>();

    public CiamService(Clock clock, Supplier<String> challengeIds) {
        this.clock = clock;
        this.challengeIds = challengeIds;
    }

    public void register(PsuIdentity identity) {
        identities.put(identity.psuId(), identity);
    }

    public void register(RegisteredDevice device) {
        devices.put(device.deviceId(), device);
    }

    public Optional<PsuIdentity> identity(String psuId) {
        return Optional.ofNullable(identities.get(psuId));
    }

    public Optional<RegisteredDevice> device(String deviceId) {
        return Optional.ofNullable(devices.get(deviceId));
    }

    public Optional<ScaChallenge> challenge(String challengeId) {
        return Optional.ofNullable(challenges.get(challengeId));
    }

    /** The PSU's devices that could answer a challenge, for the push and the QR page. */
    public List<RegisteredDevice> activeDevicesOf(String psuId) {
        return devices.values().stream()
                .filter(device -> device.psuId().equals(psuId))
                .filter(RegisteredDevice::mayAnswerChallenges)
                .toList();
    }

    public AuthenticationSession startSession(String sessionId, String brokerRequestId,
            ChallengeSubjectKind subjectKind, String subjectId) {
        AuthenticationSession session = new AuthenticationSession(
                sessionId, brokerRequestId, subjectKind, subjectId, clock.instant());
        sessions.put(sessionId, session);
        return session;
    }

    public Optional<AuthenticationSession> session(String sessionId) {
        return Optional.ofNullable(sessions.get(sessionId));
    }

    /**
     * Verifies the first factor.
     *
     * <p>Returns false for a wrong password, an unknown PSU and a locked identity alike:
     * "a failed login says only that the credentials are invalid", so the caller has
     * nothing more specific to leak.
     */
    public boolean logIn(AuthenticationSession session, String psuId, String password) {
        PsuIdentity identity = identities.get(psuId);
        if (identity == null || !identity.verifyPassword(password)) {
            return false;
        }
        session.firstFactorVerified(psuId, AuthenticationMethod.PWD);
        return true;
    }

    /**
     * Issues a challenge for the accounts the PSU chose.
     *
     * <p>"A second challenge supersedes the first": the previous one is expired, not left
     * pending, so two devices can never both hold a live challenge for one session.
     */
    public ScaChallenge issueChallenge(AuthenticationSession session, String tppId,
            String tppName, LocalDate validUntil, String summary) {
        Instant now = clock.instant();
        session.challengeId().map(challenges::get).ifPresent(ScaChallenge::expire);

        DynamicLink link = DynamicLink.forConsent(session.subjectId(), tppId, tppName,
                session.selectedAccounts(), validUntil, summary);
        ScaChallenge challenge = new ScaChallenge(challengeIds.get(), session.psuId()
                .orElseThrow(() -> new IllegalStateException("no PSU on the session")),
                session.subjectKind(), session.subjectId(), link, now);

        challenges.put(challenge.challengeId(), challenge);
        session.challengeIssued(challenge.challengeId());
        return challenge;
    }

    /**
     * Applies a device's response and, when it holds, completes the session.
     *
     * <p>Nothing in {@code deviceId} or the signature can supply a key: the device is
     * looked up here and its stored key is the only one used.
     */
    public ScaChallenge.Outcome respond(String challengeId, String deviceId,
            String signatureBase64) {
        ScaChallenge challenge = challenges.get(challengeId);
        if (challenge == null) {
            return ScaChallenge.Outcome.UNKNOWN_DEVICE;
        }
        Instant now = clock.instant();
        ScaChallenge.Outcome outcome =
                challenge.answer(devices.get(deviceId), signatureBase64, now);

        if (outcome.isApproved()) {
            sessions.values().stream()
                    .filter(session -> session.challengeId()
                            .map(challengeId::equals).orElse(false))
                    .findFirst()
                    .ifPresent(session -> session.approved(AuthenticationMethod.HWK, now));
        }
        return outcome;
    }
}
