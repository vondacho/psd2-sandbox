package ch.obya.psd2.bank.consent;

import ch.obya.psd2.authorisation.ScaStatus;
import ch.obya.psd2.authorisation.Transitions;
import java.time.Instant;

/**
 * One authorisation sub-resource of a consent (§7): the trail of one PSU's SCA, from
 * {@code received} to {@code finalised} or {@code failed}.
 *
 * <p>The {@link ScaStatus} vocabulary and the forward-only rule come from
 * {@code authorisation-kernel}, because the context map makes consent management and
 * payment initiation a shared kernel: "the specification defines one authorisation
 * process for AIS and PIS. Two copies would drift." What this class supplies is the
 * half that is <em>not</em> shared — consent's terminal set includes {@code exempted},
 * payment's does not.
 */
public final class Authorisation {

    private static final Transitions TRANSITIONS = Transitions.forConsent();

    private final AuthorisationId id;
    private final ConsentId consentId;
    private final Instant startedAt;
    private final boolean confirmationRequired;

    private ScaStatus scaStatus;
    private String psuId;
    private String challengeId;
    private Instant finalisedAt;

    Authorisation(AuthorisationId id, ConsentId consentId, Instant startedAt,
            boolean confirmationRequired) {
        this.id = id;
        this.consentId = consentId;
        this.startedAt = startedAt;
        this.confirmationRequired = confirmationRequired;
        this.scaStatus = ScaStatus.RECEIVED;
    }

    public AuthorisationId id() {
        return id;
    }

    /** "An authorisation belongs to exactly one consent." */
    public ConsentId consentId() {
        return consentId;
    }

    public ScaStatus scaStatus() {
        return scaStatus;
    }

    public String psuId() {
        return psuId;
    }

    public String challengeId() {
        return challengeId;
    }

    public Instant startedAt() {
        return startedAt;
    }

    public Instant finalisedAt() {
        return finalisedAt;
    }

    public boolean confirmationRequired() {
        return confirmationRequired;
    }

    /**
     * Moves the status forward.
     *
     * @throws IllegalStateException when the move is backwards or the status is already
     *     terminal — "scaStatus moves forward only; finalised, failed and exempted are
     *     terminal"
     */
    public void moveTo(ScaStatus next, Instant at) {
        TRANSITIONS.require(scaStatus, next);
        scaStatus = next;
        if (TRANSITIONS.isTerminal(next)) {
            finalisedAt = at;
        }
    }

    /** Records which PSU is authorising, learnt at login or from the PSU-ID header. */
    public void identifyPsu(String psuId) {
        this.psuId = psuId;
    }

    public void bindChallenge(String challengeId) {
        this.challengeId = challengeId;
    }

    public boolean isTerminal() {
        return TRANSITIONS.isTerminal(scaStatus);
    }
}
