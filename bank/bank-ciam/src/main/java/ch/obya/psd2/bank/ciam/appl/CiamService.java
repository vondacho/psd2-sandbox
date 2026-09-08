package ch.obya.psd2.bank.ciam.appl;

import ch.obya.psd2.bank.ciam.domain.*;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Supplier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * The CIAM's journey engine: login, account selection, challenge, approval.
 *
 * <p>Every rule that matters lives in the aggregates; this coordinates them and keeps the
 * one invariant that spans several — only one challenge is pending per session, so a
 * second one supersedes the first rather than running beside it.
 */
public final class CiamService {

    private static final Logger log = LoggerFactory.getLogger(CiamService.class);

    private final Clock clock;
    private final Supplier<String> challengeIds;
    private final Supplier<String> deviceIds;
    private final AuthorisationRecorder recorder;
    private final Map<String, PsuIdentity> identities = new ConcurrentHashMap<>();
    private final Map<String, RegisteredDevice> devices = new ConcurrentHashMap<>();
    private final Map<String, ScaChallenge> challenges = new ConcurrentHashMap<>();
    private final Map<String, AuthenticationSession> sessions = new ConcurrentHashMap<>();

    /** For tests that only exercise the journey and never report an outcome. */
    public CiamService(Clock clock, Supplier<String> challengeIds) {
        this(clock, challengeIds, () -> "dev-" + java.util.UUID.randomUUID(),
                (consentId, authorisationId, psuId, challengeId, accounts) -> {
                    throw new AuthorisationRecorder.RecordingFailed("no recorder configured");
                });
    }

    public CiamService(Clock clock, Supplier<String> challengeIds,
            Supplier<String> deviceIds, AuthorisationRecorder recorder) {
        this.clock = clock;
        this.challengeIds = challengeIds;
        this.deviceIds = deviceIds;
        this.recorder = recorder;
    }

    /**
     * Enrols a device. It is {@code pending} until an existing SCA confirms it, so a
     * stolen password alone can never add an approving device.
     */
    public RegisteredDevice registerDevice(String psuId, String name, String platform,
            java.security.PublicKey publicKey, boolean hardwareBacked) {
        if (identities.get(psuId) == null) {
            throw new IllegalArgumentException("no such identity");
        }
        RegisteredDevice device = new RegisteredDevice(deviceIds.get(), psuId, name,
                publicKey, hardwareBacked, DeviceStatus.PENDING, clock.instant());
        devices.put(device.deviceId(), device);
        return device;
    }

    /** Every device of a PSU, whatever its status, for the device list screen. */
    public List<RegisteredDevice> devicesOf(String psuId) {
        return devices.values().stream()
                .filter(device -> device.psuId().equals(psuId))
                .toList();
    }

    public void deny(String challengeId) {
        ScaChallenge challenge = challenges.get(challengeId);
        if (challenge != null) {
            challenge.deny(clock.instant());
            sessionFor(challengeId).ifPresent(session -> session.refused(clock.instant()));
        }
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
        return startSession(sessionId, brokerRequestId, subjectKind, subjectId, null);
    }

    public AuthenticationSession startSession(String sessionId, String brokerRequestId,
            ChallengeSubjectKind subjectKind, String subjectId, String authorisationId) {
        AuthenticationSession session = new AuthenticationSession(sessionId, brokerRequestId,
                subjectKind, subjectId, authorisationId, clock.instant());
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
        // "Leading and trailing spaces in the PSU-ID are ignored" - but not in the
        // password, where "spaces inside the password are significant".
        PsuIdentity identity = identities.get(psuId == null ? null : psuId.trim());
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
    /**
     * Applies a device's response and, when it holds, reports the outcome to consent
     * management.
     *
     * <p>The report is the point at which the PSU's approval leaves the CIAM. If it
     * fails the challenge stays approved — the PSU did approve — but the caller is told,
     * because a consent that never becomes valid is worse than an error the TPP can act
     * on.
     */
    public Approval respond(String challengeId, String deviceId, String signatureBase64) {
        ScaChallenge challenge = challenges.get(challengeId);
        if (challenge == null) {
            return Approval.refused(ScaChallenge.Outcome.UNKNOWN_DEVICE);
        }
        Instant now = clock.instant();
        ScaChallenge.Outcome outcome =
                challenge.answer(devices.get(deviceId), signatureBase64, now);
        if (!outcome.isApproved()) {
            return Approval.refused(outcome);
        }

        AuthenticationSession session = sessionFor(challengeId).orElse(null);
        if (session == null) {
            return Approval.notRecorded(outcome, "the challenge belongs to no session");
        }
        session.approved(AuthenticationMethod.HWK, now);

        try {
            AuthorisationRecorder.Recorded recorded = recorder.record(
                    session.subjectId(), session.authorisationId(),
                    session.psuId().orElseThrow(), challengeId, session.selectedAccounts());
            return Approval.recorded(outcome, recorded.scaStatus(), recorded.consentStatus());
        } catch (AuthorisationRecorder.RecordingFailed e) {
            log.error("challenge {} was approved but consent {} could not be updated: {}",
                    challengeId, session.subjectId(), e.getMessage());
            return Approval.notRecorded(outcome, e.getMessage());
        }
    }

    private java.util.Optional<AuthenticationSession> sessionFor(String challengeId) {
        return sessions.values().stream()
                .filter(session -> session.challengeId()
                        .map(challengeId::equals).orElse(false))
                .findFirst();
    }

    /**
     * What came of a device's answer: whether it verified, and if so whether consent
     * management took the outcome.
     */
    public record Approval(ScaChallenge.Outcome outcome, String scaStatus,
            String consentStatus, String recordingError) {

        static Approval refused(ScaChallenge.Outcome outcome) {
            return new Approval(outcome, null, null, null);
        }

        static Approval recorded(ScaChallenge.Outcome outcome, String scaStatus,
                String consentStatus) {
            return new Approval(outcome, scaStatus, consentStatus, null);
        }

        static Approval notRecorded(ScaChallenge.Outcome outcome, String why) {
            return new Approval(outcome, null, null, why);
        }
    }

}
