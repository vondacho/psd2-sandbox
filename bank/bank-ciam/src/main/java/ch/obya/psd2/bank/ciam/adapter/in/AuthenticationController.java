package ch.obya.psd2.bank.ciam.adapter.in;

import ch.obya.psd2.bank.ciam.appl.*;
import ch.obya.psd2.bank.ciam.domain.*;

import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * The journey the PSU walks at {@code ciam.bank.sandbox}: brokered start, login, account
 * selection, challenge.
 *
 * <p>Served as JSON rather than HTML for now. The screens are a presentation on top of
 * exactly these steps, and the scenarios assert on what the steps do, not on markup.
 */
@RestController
public class AuthenticationController {

    /** The one message a failed login may give. */
    static final String LOGIN_REFUSED = "Customer id or password is incorrect";

    private final CiamService ciam;

    public AuthenticationController(CiamService ciam) {
        this.ciam = ciam;
    }

    /**
     * The OIDC-provider brokers the PSU here, naming the consent and its authorisation.
     */
    @GetMapping("/authorize")
    public Map<String, Object> authorize(
            @RequestParam("session_id") String sessionId,
            @RequestParam("request_id") String brokerRequestId,
            @RequestParam("consent_id") String consentId,
            @RequestParam("authorisation_id") String authorisationId,
            @RequestParam(value = "tpp_name", defaultValue = "a third party") String tppName) {

        AuthenticationSession session = ciam.startSession(sessionId, brokerRequestId,
                ChallengeSubjectKind.AIS_CONSENT, consentId, authorisationId);
        session.setTppName(tppName);
        return Map.of("sessionId", session.sessionId(), "step", session.step().name(),
                // "The login page belongs to a brokered session and shows who is asking."
                "tppName", tppName, "consentId", consentId);
    }

    @PostMapping("/login")
    public ResponseEntity<Map<String, Object>> logIn(@RequestBody Credentials credentials) {
        AuthenticationSession session = ciam.session(credentials.sessionId())
                .orElseThrow(() -> new IllegalArgumentException("no such session"));

        if (!ciam.logIn(session, credentials.psuId(), credentials.password())) {
            // The same words for a wrong password, an unknown PSU and a locked identity.
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("message", LOGIN_REFUSED));
        }
        return ResponseEntity.ok(Map.of("step", session.step().name(),
                "psuId", session.psuId().orElseThrow(),
                "amr", session.authenticationMethods()));
    }

    /** The consent screen: which accounts the PSU ticked. */
    @PostMapping("/consent/selection")
    public Map<String, Object> selectAccounts(@RequestBody Selection selection) {
        AuthenticationSession session = ciam.session(selection.sessionId())
                .orElseThrow(() -> new IllegalArgumentException("no such session"));
        session.accountsSelected(selection.accounts().stream()
                .map(account -> new DynamicLink.SelectedAccount(
                        account.iban(), account.currency()))
                .toList());
        return Map.of("step", session.step().name(),
                "selected", session.selectedAccounts().size());
    }

    /** Issues the challenge and returns what the QR page needs. */
    @PostMapping("/sca/challenges")
    public Map<String, Object> issueChallenge(@RequestBody ChallengeRequest request) {
        AuthenticationSession session = ciam.session(request.sessionId())
                .orElseThrow(() -> new IllegalArgumentException("no such session"));

        ScaChallenge challenge = ciam.issueChallenge(session, request.tppId(),
                session.tppName(), request.validUntil(), request.summary());

        return Map.of(
                "challengeId", challenge.challengeId(),
                "expiresAt", challenge.expiresAt().toString(),
                "qr", challenge.qrPayload("https://ciam.bank.sandbox/sca"),
                // What the PSU is told they are approving, in words.
                "summary", challenge.dynamicLink().summary(),
                "tppName", challenge.dynamicLink().tppName());
    }

    public record Credentials(String sessionId, String psuId, String password) {
    }

    public record Selection(String sessionId, List<Account> accounts) {
        public record Account(String iban, String currency) {
        }
    }

    public record ChallengeRequest(String sessionId, String tppId,
            java.time.LocalDate validUntil, String summary) {
    }
}
