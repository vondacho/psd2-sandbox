package ch.obya.psd2.bank.consent;

import ch.obya.psd2.bank.consent.domain.*;
import ch.obya.psd2.bank.consent.appl.*;

import ch.obya.psd2.authorisation.ScaStatus;
import java.time.Instant;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The invariants of {@code consent-management.ddm}'s Authorisation aggregate, and the
 * half of the shared kernel that belongs to consent management rather than to payment.
 */
class AuthorisationTest {

    private static final Instant NOW = Instant.parse("2026-09-06T10:00:00Z");

    private Authorisation authorisation() {
        return new Authorisation(new AuthorisationId("123auth567"),
                new ConsentId("123cons456"), NOW, false);
    }

    @Test
    @DisplayName("scaStatus moves forward only")
    void forwardOnly() {
        Authorisation authorisation = authorisation();

        authorisation.moveTo(ScaStatus.PSU_AUTHENTICATED, NOW);
        authorisation.moveTo(ScaStatus.STARTED, NOW);

        assertThrows(IllegalStateException.class,
                () -> authorisation.moveTo(ScaStatus.PSU_IDENTIFIED, NOW),
                "backwards must be refused");
    }

    @Test
    @DisplayName("finalised, failed and exempted are terminal for a consent authorisation")
    void consentTerminalsIncludeExempted() {
        for (ScaStatus terminal :
                new ScaStatus[] {ScaStatus.FINALISED, ScaStatus.FAILED, ScaStatus.EXEMPTED}) {
            Authorisation authorisation = authorisation();
            authorisation.moveTo(terminal, NOW);

            assertTrue(authorisation.isTerminal(), terminal + " must be terminal");
            assertEquals(NOW, authorisation.finalisedAt());
            assertThrows(IllegalStateException.class,
                    () -> authorisation.moveTo(ScaStatus.FINALISED, NOW),
                    "nothing follows a terminal status");
        }
    }

    @Test
    @DisplayName("exempted is terminal HERE but not for a payment — the kernel is parameterised")
    void theTerminalSetIsNotShared() {
        assertTrue(ch.obya.psd2.authorisation.Transitions.forConsent()
                .isTerminal(ScaStatus.EXEMPTED));
        assertFalse(ch.obya.psd2.authorisation.Transitions.forPayment()
                .isTerminal(ScaStatus.EXEMPTED),
                "payment-initiation.ddm lists only finalised and failed as terminal, "
                        + "which is why the kernel holds no Authorisation entity");
    }

    @Test
    @DisplayName("An authorisation belongs to exactly one consent")
    void belongsToOneConsent() {
        assertEquals(new ConsentId("123cons456"), authorisation().consentId());
    }
}
