package ch.obya.psd2.oidc;

import ch.obya.psd2.oidc.domain.*;
import ch.obya.psd2.oidc.appl.*;

import ch.obya.psd2.spec.OrganizationIdentifier;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Covers {@code docs/design/features/2-connect-the-bank-from-the-tpp/
 * validate-the-scope-against-the-consent.feature}.
 */
class ScopeValidationTest {

    private static final ClientRegistration TPP = new ClientRegistration(
            OrganizationIdentifier.parse("PSDDE-BAFIN-123456"), "TPP Fintech GmbH",
            Set.of(Psd2Role.AISP, Psd2Role.PISP),
            List.of("https://tpp.sandbox/xs2a/callback/bank"), Set.of("bwcK0"));

    private static final ClientRegistration TPP_C = new ClientRegistration(
            OrganizationIdentifier.parse("PSDDE-BAFIN-654321"), "C Pay",
            Set.of(Psd2Role.PISP), List.of("https://tpp-c.sandbox/cb"), Set.of("other"));

    /** The Bank's answer for each resource, as the internal contract would give it. */
    private static ScopeValidation validationOver(Map<String, ResourceStatus> resources) {
        return new ScopeValidation((resourceId, clientId) -> {
            ResourceStatus status = resources.get(resourceId);
            return status == null ? ResourceStatus.absent() : status;
        });
    }

    private static ScopeValidation nominal() {
        return validationOver(Map.of(
                "123cons456", new ResourceStatus(true, true, "received"),
                "333cons444", new ResourceStatus(true, false, "received")));
    }

    // ---- the grammar -----------------------------------------------------------------

    @Test
    @DisplayName("AIS:123cons456 offline_access is accepted")
    void resourceWithOfflineAccess() {
        RequestedScope scope = RequestedScope.parse("AIS:123cons456 offline_access");

        assertTrue(scope.isAccepted());
        assertEquals(ScopeKind.AIS, scope.target().kind());
        assertEquals("123cons456", scope.target().resourceId());
        assertTrue(scope.offlineAccess());
    }

    @Test
    @DisplayName("AIS:123cons456 alone is accepted")
    void resourceWithoutOfflineAccess() {
        RequestedScope scope = RequestedScope.parse("AIS:123cons456");

        assertTrue(scope.isAccepted());
        assertFalse(scope.offlineAccess());
    }

    @Test
    @DisplayName("Two AIS scopes are refused")
    void twoResourcesOfTheSameKind() {
        assertEquals(AuthorizationDecision.INVALID_SCOPE,
                nominal().validate(Optional.of(TPP), "AIS:123cons456 AIS:111cons222").error());
    }

    @Test
    @DisplayName("An AIS and a PIS scope together are refused")
    void twoResourcesOfDifferentKinds() {
        assertEquals(AuthorizationDecision.INVALID_SCOPE,
                nominal().validate(Optional.of(TPP), "AIS:123cons456 PIS:pay001").error());
    }

    @Test
    @DisplayName("A scope without any resource is refused")
    void offlineAccessAlone() {
        assertEquals(AuthorizationDecision.INVALID_SCOPE,
                nominal().validate(Optional.of(TPP), "offline_access").error());
    }

    @Test
    @DisplayName("An unknown scope word is refused")
    void unknownWord() {
        AuthorizationDecision decision =
                nominal().validate(Optional.of(TPP), "AIS:123cons456 admin");

        assertEquals(AuthorizationDecision.INVALID_SCOPE, decision.error());
        assertEquals("unknown scope admin", decision.errorDescription());
    }

    @Test
    @DisplayName("An AIS scope with an empty id is refused")
    void emptyResourceId() {
        assertEquals(AuthorizationDecision.INVALID_SCOPE,
                nominal().validate(Optional.of(TPP), "AIS:").error());
    }

    // ---- the resource ----------------------------------------------------------------

    @Test
    @DisplayName("A received consent of the TPP is accepted")
    void receivedConsentOfTheCaller() {
        AuthorizationDecision decision =
                nominal().validate(Optional.of(TPP), "AIS:123cons456 offline_access");

        assertTrue(decision.proceed());
        assertEquals("123cons456", decision.target().resourceId());
        assertTrue(decision.offlineAccess());
    }

    @Test
    @DisplayName("An unknown consent is refused with 'unknown resource'")
    void unknownConsent() {
        AuthorizationDecision decision =
                nominal().validate(Optional.of(TPP), "AIS:999cons000");

        assertEquals(AuthorizationDecision.INVALID_SCOPE, decision.error());
        assertEquals("unknown resource", decision.errorDescription());
    }

    @Test
    @DisplayName("A consent of another TPP is refused and logged with both client ids")
    void consentOfAnotherTpp() {
        List<String> log = new ArrayList<>();
        ScopeValidation validation = new ScopeValidation(
                (resourceId, clientId) -> new ResourceStatus(true, false, "received"),
                (clientId, message) -> log.add(clientId + " | " + message));

        AuthorizationDecision decision = validation.validate(Optional.of(TPP), "AIS:333cons444");

        assertEquals(AuthorizationDecision.INVALID_SCOPE, decision.error());
        assertEquals("unknown resource", decision.errorDescription(),
                "the caller must not learn that the resource exists but is someone else's");
        assertTrue(log.stream().anyMatch(entry -> entry.contains("PSDDE-BAFIN-123456")
                && entry.contains("333cons444")), "but the refusal is logged: " + log);
    }

    @Test
    @DisplayName("An already valid consent cannot be authorised again")
    void alreadyValidConsent() {
        ScopeValidation validation = validationOver(
                Map.of("123cons456", new ResourceStatus(true, true, "valid")));

        AuthorizationDecision decision = validation.validate(Optional.of(TPP), "AIS:123cons456");

        assertEquals("resource not in status received", decision.errorDescription());
    }

    @Test
    @DisplayName("A rejected consent is refused")
    void rejectedConsent() {
        ScopeValidation validation = validationOver(
                Map.of("123cons456", new ResourceStatus(true, true, "rejected")));

        assertEquals(AuthorizationDecision.INVALID_SCOPE,
                validation.validate(Optional.of(TPP), "AIS:123cons456").error());
    }

    @Test
    @DisplayName("A consent whose authorisation is already started is still accepted")
    void abandonedFirstAttemptStillProceeds() {
        // The consent is still 'received'; only its authorisation moved on. The
        // OIDC-provider cannot see scaStatus, and must not need to.
        ScopeValidation validation = validationOver(
                Map.of("123cons456", new ResourceStatus(true, true, "received")));

        assertTrue(validation.validate(Optional.of(TPP), "AIS:123cons456").proceed());
    }

    // ---- roles gate the scope kinds --------------------------------------------------

    @Test
    @DisplayName("C with PISP only may not request AIS scopes")
    void pispOnlyMayNotRequestAis() {
        AuthorizationDecision decision = nominal().validate(Optional.of(TPP_C), "AIS:123cons456");

        assertEquals(AuthorizationDecision.INVALID_SCOPE, decision.error());
        assertEquals("the client does not hold AISP", decision.errorDescription());
    }

    @Test
    @DisplayName("The role is checked before the Bank is called")
    void roleIsCheckedBeforeTheInternalCall() {
        List<String> lookups = new ArrayList<>();
        ScopeValidation validation = new ScopeValidation((resourceId, clientId) -> {
            lookups.add(resourceId);
            return new ResourceStatus(true, true, "received");
        });

        validation.validate(Optional.of(TPP_C), "AIS:123cons456");

        assertTrue(lookups.isEmpty(),
                "a client that could not hold the scope never learns whether it exists");
    }

    @Test
    @DisplayName("An unregistered client id is refused at /authorize")
    void unknownClient() {
        assertEquals(AuthorizationDecision.UNAUTHORIZED_CLIENT,
                nominal().validate(Optional.empty(), "AIS:123cons456").error());
    }

    // ---- the Bank being down is not a refusal ----------------------------------------

    @Test
    @DisplayName("Consent management unreachable yields temporarily_unavailable")
    void bankUnreachable() {
        ScopeValidation validation = new ScopeValidation((resourceId, clientId) -> {
            throw new ConsentLookup.LookupUnavailable("timed out after 3 seconds");
        });

        AuthorizationDecision decision = validation.validate(Optional.of(TPP), "AIS:123cons456");

        assertEquals(AuthorizationDecision.TEMPORARILY_UNAVAILABLE, decision.error());
        assertEquals("the Bank is temporarily unavailable", decision.errorDescription());
    }
}
