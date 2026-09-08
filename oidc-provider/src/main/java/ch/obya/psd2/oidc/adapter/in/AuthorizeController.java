package ch.obya.psd2.oidc.adapter.in;

import ch.obya.psd2.oidc.appl.*;
import ch.obya.psd2.oidc.domain.*;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * {@code /authorize} — RFC 6749 §4.1.1, with the PSD2 scope grammar of §13.1.
 *
 * <p>Errors travel back to the TPP as a redirect carrying the state, not as an error
 * page — with one exception. If the redirect URI itself is not registered there is
 * nowhere safe to redirect to, so the error is shown instead. Redirecting to an
 * unverified URI is how open redirectors are built.
 */
@RestController
public class AuthorizeController {

    private final AuthorizationService authorization;
    private final String ciamBaseUrl;
    private final String ownBrowserUrl;

    public AuthorizeController(AuthorizationService authorization,
            @Value("${sandbox.ciam.base-url:http://localhost:9443}") String ciamBaseUrl,
            @Value("${sandbox.oidc.browser-base-url:http://localhost:7080}")
            String ownBrowserUrl) {
        this.authorization = authorization;
        this.ciamBaseUrl = ciamBaseUrl;
        this.ownBrowserUrl = ownBrowserUrl;
    }

    @GetMapping("/authorize")
    public ResponseEntity<?> authorize(
            @RequestParam("response_type") String responseType,
            @RequestParam("client_id") String clientId,
            @RequestParam("redirect_uri") String redirectUri,
            @RequestParam("scope") String scope,
            @RequestParam("state") String state,
            @RequestParam("code_challenge") String codeChallenge,
            @RequestParam(value = "code_challenge_method", defaultValue = "S256")
            String codeChallengeMethod,
            @RequestParam(value = "authorisation_id", required = false) String authorisationId) {

        if (!"code".equals(responseType)) {
            return redirect(redirectUri, "unsupported_response_type",
                    "only the authorization code flow is served", state);
        }
        if (!"S256".equals(codeChallengeMethod)) {
            return redirect(redirectUri, AuthorizationDecision.INVALID_REQUEST,
                    "only S256 is accepted", state);
        }

        AuthorizationService.Started started =
                authorization.start(clientId, redirectUri, scope, state, codeChallenge);

        if (!started.proceed()) {
            if (!started.redirectSafe()) {
                // Nowhere safe to send this.
                return ResponseEntity.badRequest().body(Map.of(
                        "error", started.error(),
                        "error_description", started.errorDescription()));
            }
            return redirect(redirectUri, started.error(), started.errorDescription(), state);
        }

        // Broker the PSU to the Bank's CIAM's own screens, naming the consent, its
        // authorisation, and where to send the browser once the PSU has approved.
        String brokerTo = ciamBaseUrl + "/ui/index.html"
                + "?session_id=" + encode(started.requestId())
                + "&request_id=" + encode(started.requestId())
                + "&consent_id=" + encode(started.target().resourceId())
                + "&authorisation_id=" + encode(
                        authorisationId == null ? "" : authorisationId)
                + "&tpp_name=" + encode(authorization.client(clientId)
                        .map(ClientRegistration::legalName).orElse("a third party"))
                + "&return_to=" + encode(ownBrowserUrl + "/broker/callback");

        return ResponseEntity.status(HttpStatus.FOUND)
                .location(URI.create(brokerTo)).build();
    }

    /**
     * The CIAM's back-channel callback: the PSU authenticated and approved, so a code
     * may be issued and the browser sent back to the TPP.
     */
    @GetMapping("/broker/callback")
    public ResponseEntity<?> brokerCallback(
            @RequestParam("request_id") String requestId,
            @RequestParam("sub") String subject,
            @RequestParam(value = "acr", defaultValue = "urn:bank:psd2:sca") String acr,
            @RequestParam(value = "amr", defaultValue = "pwd,hwk") String amr) {

        Optional<AuthorizationService.PendingRequest> pending = authorization.pending(requestId);
        if (pending.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", AuthorizationDecision.INVALID_REQUEST,
                    "error_description", "no such authorization request"));
        }
        AuthorizationService.PendingRequest request = pending.get();

        return authorization.issueCode(requestId, subject, acr, List.of(amr.split(",")))
                .<ResponseEntity<?>>map(code -> ResponseEntity.status(HttpStatus.FOUND)
                        .location(URI.create(request.redirectUri()
                                + "?code=" + encode(code.code())
                                + "&state=" + encode(request.state()))).build())
                .orElseGet(() -> ResponseEntity.badRequest().body(Map.of(
                        "error", AuthorizationDecision.INVALID_REQUEST,
                        "error_description", "the request yielded a code already")));
    }

    private static ResponseEntity<?> redirect(String redirectUri, String error,
            String description, String state) {
        return ResponseEntity.status(HttpStatus.FOUND).location(URI.create(redirectUri
                + "?error=" + encode(error)
                + "&error_description=" + encode(description)
                + "&state=" + encode(state))).build();
    }

    private static String encode(String value) {
        return URLEncoder.encode(value == null ? "" : value, StandardCharsets.UTF_8);
    }
}
