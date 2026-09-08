package ch.obya.psd2.bank.ciam.domain;

import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * One journey from the OIDC-provider's redirect to a signed approval.
 *
 * <p>The order is the security property, so it is enforced here rather than trusted to
 * the screens: "the second factor is requested only after the first factor is verified
 * and the risk assessment did not refuse", and "a challenge is issued only after the
 * accounts were selected".
 */
public final class AuthenticationSession {

    private final String sessionId;
    private final String brokerRequestId;
    private final String authorisationId;
    private final ChallengeSubjectKind subjectKind;
    private final String subjectId;
    private final Instant startedAt;

    private SessionStep step = SessionStep.IDENTIFIED;
    private String psuId;
    private final Set<AuthenticationMethod> methods = EnumSet.noneOf(AuthenticationMethod.class);
    private final List<DynamicLink.SelectedAccount> selectedAccounts = new ArrayList<>();
    private String challengeId;
    private Instant completedAt;
    private boolean riskRefused;

    private String tppName = "a third party";

    public AuthenticationSession(String sessionId, String brokerRequestId,
            ChallengeSubjectKind subjectKind, String subjectId, Instant startedAt) {
        this(sessionId, brokerRequestId, subjectKind, subjectId, null, startedAt);
    }

    public AuthenticationSession(String sessionId, String brokerRequestId,
            ChallengeSubjectKind subjectKind, String subjectId, String authorisationId,
            Instant startedAt) {
        this.sessionId = sessionId;
        this.brokerRequestId = brokerRequestId;
        this.authorisationId = authorisationId;
        this.subjectKind = subjectKind;
        this.subjectId = subjectId;
        this.startedAt = startedAt;
    }

    public String sessionId() {
        return sessionId;
    }

    /** Ties the session to the one authorization request that started it. */
    public String brokerRequestId() {
        return brokerRequestId;
    }

    /**
     * The authorisation sub-resource this session authorises, learnt from the brokered
     * request. The CIAM needs it to report the outcome, and cannot derive it: only
     * consent management knows which authorisation belongs to which consent.
     */
    public String authorisationId() {
        return authorisationId;
    }

    /** Who is asking, for the login page and the device screen. */
    public String tppName() {
        return tppName;
    }

    public void setTppName(String tppName) {
        this.tppName = tppName;
    }

    public ChallengeSubjectKind subjectKind() {
        return subjectKind;
    }

    /** "A session names exactly one subject." */
    public String subjectId() {
        return subjectId;
    }

    public SessionStep step() {
        return step;
    }

    public Optional<String> psuId() {
        return Optional.ofNullable(psuId);
    }

    public Instant startedAt() {
        return startedAt;
    }

    public Instant completedAt() {
        return completedAt;
    }

    public Optional<String> challengeId() {
        return Optional.ofNullable(challengeId);
    }

    public List<DynamicLink.SelectedAccount> selectedAccounts() {
        return List.copyOf(selectedAccounts);
    }

    /** The {@code amr} array of the ID token, in a stable order. */
    public List<String> authenticationMethods() {
        return methods.stream().map(AuthenticationMethod::claim).toList();
    }

    /** True once both a knowledge and a possession element were used — RTS art. 4. */
    public boolean hasTwoIndependentFactors() {
        return methods.stream().anyMatch(AuthenticationMethod::isKnowledge)
                && methods.stream().anyMatch(AuthenticationMethod::isPossession);
    }

    /** "A successful first factor alone grants nothing" — it only moves the step. */
    public void firstFactorVerified(String psuId, AuthenticationMethod method) {
        this.psuId = psuId;
        methods.add(method);
        step = SessionStep.FIRST_FACTOR_VERIFIED;
    }

    public void riskAssessed(boolean refuse) {
        require(SessionStep.FIRST_FACTOR_VERIFIED, "risk is assessed after the first factor");
        this.riskRefused = refuse;
        step = refuse ? SessionStep.REFUSED : SessionStep.RISK_ASSESSED;
    }

    /** The accounts the PSU ticked on the consent screen. */
    public void accountsSelected(List<DynamicLink.SelectedAccount> selection) {
        if (step != SessionStep.FIRST_FACTOR_VERIFIED && step != SessionStep.RISK_ASSESSED) {
            throw new IllegalStateException(
                    "accounts are selected after the first factor, not in step " + step);
        }
        if (riskRefused) {
            throw new IllegalStateException("the risk assessment refused this session");
        }
        selectedAccounts.clear();
        selectedAccounts.addAll(selection);
        step = SessionStep.ACCOUNTS_SELECTED;
    }

    /**
     * @throws IllegalStateException with the message the screens surface —
     *     {@code accounts not selected} — when a challenge is asked for too early
     */
    public void challengeIssued(String challengeId) {
        if (step != SessionStep.ACCOUNTS_SELECTED && step != SessionStep.CHALLENGE_ISSUED) {
            throw new IllegalStateException("accounts not selected");
        }
        this.challengeId = challengeId;
        step = SessionStep.CHALLENGE_ISSUED;
    }

    public void approved(AuthenticationMethod method, Instant at) {
        require(SessionStep.CHALLENGE_ISSUED, "nothing is approved before a challenge");
        methods.add(method);
        step = SessionStep.APPROVED;
        completedAt = at;
    }

    public void refused(Instant at) {
        step = SessionStep.REFUSED;
        completedAt = at;
    }

    /**
     * "An ID token is produced only for a session whose challenge was approved."
     */
    public boolean mayIssueIdToken() {
        return step == SessionStep.APPROVED && hasTwoIndependentFactors();
    }

    private void require(SessionStep expected, String because) {
        if (step != expected) {
            throw new IllegalStateException(because + " (step is " + step + ")");
        }
    }
}
