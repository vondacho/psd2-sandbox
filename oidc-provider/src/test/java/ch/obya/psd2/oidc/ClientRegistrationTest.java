package ch.obya.psd2.oidc;

import ch.obya.psd2.oidc.domain.*;
import ch.obya.psd2.oidc.appl.*;

import ch.obya.psd2.spec.OrganizationIdentifier;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Covers the redirect-URI and certificate-binding rules of
 * {@code register-the-tpp-client-at-the-oidc-provider.feature}.
 */
class ClientRegistrationTest {

    private static final String CALLBACK = "https://tpp.sandbox/xs2a/callback/bank";

    private final ClientRegistration tpp = new ClientRegistration(
            OrganizationIdentifier.parse("PSDDE-BAFIN-123456"), "TPP Fintech GmbH",
            Set.of(Psd2Role.AISP, Psd2Role.PISP), List.of(CALLBACK),
            Set.of("bwcK0", "rotated"));

    @Test
    @DisplayName("The registered callback matches")
    void exactMatch() {
        assertTrue(tpp.allowsRedirectTo(CALLBACK));
    }

    @Test
    @DisplayName("A different path is refused")
    void differentPath() {
        assertFalse(tpp.allowsRedirectTo("https://tpp.sandbox/xs2a/callback/other"));
    }

    @Test
    @DisplayName("An added query parameter is refused")
    void addedQueryParameter() {
        assertFalse(tpp.allowsRedirectTo(CALLBACK + "?extra=1"));
    }

    @Test
    @DisplayName("A different scheme is refused")
    void differentScheme() {
        assertFalse(tpp.allowsRedirectTo("http://tpp.sandbox/xs2a/callback/bank"));
    }

    @Test
    @DisplayName("Case differs in the host only: accepted")
    void hostIsCaseInsensitive() {
        assertTrue(tpp.allowsRedirectTo("https://TPP.SANDBOX/xs2a/callback/bank"));
    }

    @Test
    @DisplayName("A path whose case differs is refused — only the host is case-insensitive")
    void pathIsCaseSensitive() {
        assertFalse(tpp.allowsRedirectTo("https://tpp.sandbox/XS2A/callback/bank"));
    }

    @Test
    @DisplayName("A client may hold more than one certificate binding so certificates can rotate")
    void twoBindings() {
        assertTrue(tpp.isBoundTo("bwcK0"));
        assertTrue(tpp.isBoundTo("rotated"));
        assertFalse(tpp.isBoundTo("someone-else"));
    }

    @Test
    @DisplayName("The client's PSD2 roles gate the scope kinds")
    void rolesGateScopeKinds() {
        assertTrue(tpp.holds(Psd2Role.AISP));
        assertFalse(tpp.holds(Psd2Role.PIISP));
    }
}
