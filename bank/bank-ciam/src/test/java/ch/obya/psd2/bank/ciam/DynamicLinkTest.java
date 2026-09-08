package ch.obya.psd2.bank.ciam;

import ch.obya.psd2.bank.ciam.domain.*;
import ch.obya.psd2.bank.ciam.appl.*;

import ch.obya.psd2.bank.ciam.domain.DynamicLink.SelectedAccount;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

/**
 * Covers {@code docs/design/features/3-authenticate-and-approve-at-the-bank/
 * issue-a-challenge-with-dynamic-linking.feature}, the canonical-string rule.
 *
 * <p>These are the assertions worth having: the hash is what the PSU's approval is bound
 * to, so every fact that changes what they are approving must change it, and nothing else
 * may.
 */
class DynamicLinkTest {

    private static final String CONSENT = "123cons456";
    private static final String TPP = "PSDDE-BAFIN-123456";
    private static final LocalDate UNTIL = LocalDate.of(2026, 12, 5);
    private static final SelectedAccount MAIN =
            new SelectedAccount("DE23100100100123456789", "EUR");
    private static final SelectedAccount SAVINGS =
            new SelectedAccount("DE89370400440532013000", "EUR");

    @Test
    @DisplayName("The canonical string for Main Account until 2026-12-05")
    void theCanonicalString() {
        assertEquals("123cons456|PSDDE-BAFIN-123456|DE23100100100123456789:EUR|2026-12-05",
                DynamicLink.canonicalString(CONSENT, TPP, List.of(MAIN), UNTIL));
    }

    @Test
    @DisplayName("The same inputs always give the same hash")
    void stable() {
        assertEquals(DynamicLink.hashOf(CONSENT, TPP, List.of(MAIN), UNTIL),
                DynamicLink.hashOf(CONSENT, TPP, List.of(MAIN), UNTIL));
    }

    @Test
    @DisplayName("A different account changes the hash")
    void accountMatters() {
        assertNotEquals(DynamicLink.hashOf(CONSENT, TPP, List.of(MAIN), UNTIL),
                DynamicLink.hashOf(CONSENT, TPP, List.of(SAVINGS), UNTIL));
    }

    @Test
    @DisplayName("A different validity changes the hash")
    void validityMatters() {
        assertNotEquals(DynamicLink.hashOf(CONSENT, TPP, List.of(MAIN), UNTIL),
                DynamicLink.hashOf(CONSENT, TPP, List.of(MAIN), UNTIL.plusDays(1)));
    }

    @Test
    @DisplayName("A different consent id changes the hash even for the same accounts")
    void consentMatters() {
        assertNotEquals(DynamicLink.hashOf(CONSENT, TPP, List.of(MAIN), UNTIL),
                DynamicLink.hashOf("111cons222", TPP, List.of(MAIN), UNTIL));
    }

    @Test
    @DisplayName("A different TPP changes the hash")
    void tppMatters() {
        assertNotEquals(DynamicLink.hashOf(CONSENT, TPP, List.of(MAIN), UNTIL),
                DynamicLink.hashOf(CONSENT, "PSDDE-BAFIN-654321", List.of(MAIN), UNTIL));
    }

    @Test
    @DisplayName("The order of selected accounts does not matter")
    void orderDoesNotMatter() {
        assertEquals(DynamicLink.hashOf(CONSENT, TPP, List.of(MAIN, SAVINGS), UNTIL),
                DynamicLink.hashOf(CONSENT, TPP, List.of(SAVINGS, MAIN), UNTIL));
    }

    @Test
    @DisplayName("Two currencies of one IBAN are two list entries")
    void multicurrencyIsTwoEntries() {
        String canonical = DynamicLink.canonicalString(CONSENT, TPP,
                List.of(new SelectedAccount("DE11", "USD"), new SelectedAccount("DE11", "EUR")),
                UNTIL);

        assertEquals("123cons456|PSDDE-BAFIN-123456|DE11:EUR,DE11:USD|2026-12-05", canonical);
    }

    @Test
    @DisplayName("IBAN spacing is not part of the hash — a screen may group digits")
    void spacingIsIrrelevant() {
        assertEquals(
                DynamicLink.hashOf(CONSENT, TPP, List.of(MAIN), UNTIL),
                DynamicLink.hashOf(CONSENT, TPP,
                        List.of(new SelectedAccount("DE23 1001 0010 0123 4567 89", "EUR")),
                        UNTIL));
    }

    @Test
    @DisplayName("The dynamic link record keeps a human summary")
    void keepsWhatThePsuWasShown() {
        DynamicLink link = DynamicLink.forConsent(CONSENT, TPP,
                "TPP App (TPP Fintech GmbH)", List.of(MAIN), UNTIL,
                "accounts and balances of DE23 …7 89 until 2026-12-05");

        assertEquals("TPP App (TPP Fintech GmbH)", link.tppName());
        assertEquals("accounts and balances of DE23 …7 89 until 2026-12-05", link.summary());
        assertEquals(64, link.hash().length(), "SHA-256 as hex");
    }
}
