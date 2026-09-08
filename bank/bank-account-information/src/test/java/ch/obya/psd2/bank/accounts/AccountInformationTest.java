package ch.obya.psd2.bank.accounts;

import ch.obya.psd2.bank.accounts.appl.*;
import ch.obya.psd2.bank.accounts.domain.*;
import ch.obya.psd2.bank.consent.appl.*;
import ch.obya.psd2.bank.consent.domain.*;
import ch.obya.psd2.spec.OrganizationIdentifier;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Covers {@code serve-get-v1-accounts-from-the-consent.feature} and the resource-id
 * rules of {@code tokenise-account-identifiers.feature}.
 *
 * <p>The ledger is a map standing in for Microcks: what is under test is the projection
 * and the filtering, not HTTP.
 */
class AccountInformationTest {

    private static final Instant NOW =
            LocalDate.of(2026, 9, 6).atStartOfDay(ZoneOffset.UTC).toInstant();
    private static final OrganizationIdentifier TPP =
            OrganizationIdentifier.parse("PSDDE-BAFIN-123456");
    private static final String MAIN = "DE23100100100123456789";
    private static final String SAVINGS = "DE89370400440532013000";

    /** The ledger as the adapter would present it, keyed by customer and IBAN. */
    private final Map<String, LedgerAccounts.LedgerAccount> ledger = new HashMap<>();
    private final LedgerAccounts port = (customerId, iban, currency) ->
            Optional.ofNullable(ledger.get(customerId + "|" + iban));
    private final AccountInformation accounts = new AccountInformation(port);

    private ConsentService consents;

    @BeforeEach
    void setUp() {
        ledger.put("anna.mueller|" + MAIN, new LedgerAccounts.LedgerAccount(MAIN, "EUR",
                "Girokonto", "Girokonto", "CURRENT", true, "Anna Müller",
                new BigDecimal("1250.30"), new BigDecimal("1180.30"), NOW));
        ledger.put("anna.mueller|" + SAVINGS, new LedgerAccounts.LedgerAccount(SAVINGS, "EUR",
                "Sparkonto", "Sparkonto", "SAVINGS", true, "Anna Müller",
                new BigDecimal("8400.00"), new BigDecimal("8400.00"), NOW));
        consents = new ConsentService(Clock.fixed(NOW, ZoneOffset.UTC),
                SandboxLimits.defaults(), () -> "123cons456", () -> "123auth567");
    }

    /** A consent authorised over the given IBANs, as the CIAM would have left it. */
    private Consent authorisedOver(Set<AccessType> granted, String... ibans) {
        ConsentService.Created created = consents.create(new ConsentRequest(TPP,
                AccountAccess.bankOffered(), true, LocalDate.of(2026, 12, 5), 4, false,
                "https://tpp.sandbox/cb", null, null));
        consents.recordOutcome(created.consent().id(), created.authorisation().id(),
                new AuthorisationOutcome("anna.mueller", "chl-01J8",
                        java.util.Arrays.stream(ibans)
                                .map(iban -> new AuthorisationOutcome.ChosenAccount(
                                        AccountReference.ofIban(iban, "EUR"), "EUR", granted))
                                .toList()));
        return created.consent();
    }

    @Test
    @DisplayName("Two selected accounts")
    void twoSelectedAccounts() {
        Consent consent = authorisedOver(Set.of(AccessType.ACCOUNTS), MAIN, SAVINGS);

        List<AccountResource> list = accounts.list(consent, false);

        assertEquals(2, list.size());
        assertEquals(List.of(MAIN, SAVINGS), list.stream().map(AccountResource::iban).toList());
        assertEquals("Girokonto", list.getFirst().product());
    }

    @Test
    @DisplayName("One selected account: the other is absent")
    void onlyWhatWasSelected() {
        Consent consent = authorisedOver(Set.of(AccessType.ACCOUNTS), MAIN);

        List<AccountResource> list = accounts.list(consent, false);

        assertEquals(1, list.size());
        assertEquals(MAIN, list.getFirst().iban());
    }

    @Test
    @DisplayName("No balances without withBalance")
    void balancesOnlyOnRequest() {
        Consent consent =
                authorisedOver(Set.of(AccessType.ACCOUNTS, AccessType.BALANCES), MAIN);

        assertTrue(accounts.list(consent, false).getFirst().balances().isEmpty());
        assertFalse(accounts.list(consent, true).getFirst().balances().isEmpty());
    }

    @Test
    @DisplayName("Balances need the consent to grant them, not only the caller to ask")
    void balancesNeedTheAccessType() {
        Consent consent = authorisedOver(Set.of(AccessType.ACCOUNTS), MAIN);

        assertTrue(accounts.list(consent, true).getFirst().balances().isEmpty(),
                "withBalance cannot widen what the PSU consented to");
    }

    @Test
    @DisplayName("The ledger's two figures become closingBooked and interimAvailable")
    void balancesAreTranslated() {
        Consent consent =
                authorisedOver(Set.of(AccessType.ACCOUNTS, AccessType.BALANCES), MAIN);

        AccountResource account = accounts.list(consent, true).getFirst();

        assertEquals(new BigDecimal("1250.30"),
                account.balanceOf(BalanceType.CLOSING_BOOKED).orElseThrow().amount());
        assertEquals(new BigDecimal("1180.30"),
                account.balanceOf(BalanceType.INTERIM_AVAILABLE).orElseThrow().amount());
    }

    @Test
    @DisplayName("An account closed at the bank since the consent")
    void closedAccountDisappears() {
        Consent consent = authorisedOver(Set.of(AccessType.ACCOUNTS), MAIN, SAVINGS);
        LedgerAccounts.LedgerAccount main = ledger.get("anna.mueller|" + MAIN);
        ledger.put("anna.mueller|" + MAIN, new LedgerAccounts.LedgerAccount(main.iban(),
                main.currency(), main.name(), main.product(), main.accountType(),
                false, main.holderName(), main.booked(), main.available(), main.asOf()));

        List<AccountResource> list = accounts.list(consent, false);

        assertEquals(1, list.size());
        assertEquals(SAVINGS, list.getFirst().iban());
    }

    @Test
    @DisplayName("A renamed account shows its new name")
    void renamedAccount() {
        Consent consent = authorisedOver(Set.of(AccessType.ACCOUNTS), MAIN);
        LedgerAccounts.LedgerAccount main = ledger.get("anna.mueller|" + MAIN);
        ledger.put("anna.mueller|" + MAIN, new LedgerAccounts.LedgerAccount(main.iban(),
                main.currency(), "Mein Hauptkonto", main.product(), main.accountType(),
                true, main.holderName(), main.booked(), main.available(), main.asOf()));

        assertEquals("Mein Hauptkonto", accounts.list(consent, false).getFirst().name(),
                "the list reflects the ledger at call time");
    }

    @Test
    @DisplayName("A new account opened after the consent is not listed")
    void newAccountIsNotListed() {
        Consent consent = authorisedOver(Set.of(AccessType.ACCOUNTS), MAIN);
        ledger.put("anna.mueller|DE11999999999999999999",
                new LedgerAccounts.LedgerAccount("DE11999999999999999999", "EUR", "Neu",
                        "Girokonto", "CURRENT", true, "Anna Müller",
                        BigDecimal.ZERO, BigDecimal.ZERO, NOW));

        assertEquals(1, accounts.list(consent, false).size(),
                "the consent never granted it, so it has no resourceId and cannot exist");
    }

    @Test
    @DisplayName("The owner name is never served, because no access model asks for it yet")
    void ownerNameNeedsItsAccessType() {
        // A bank-offered request asks for accounts and balances. ownerName arrives with
        // increment 2 ("Serve the owner name and additional information", §14.18), which
        // needs an ownerNameRequested field on AccountAccess that the model does not have
        // yet. Until then consent management trims OWNER_NAME away, whatever the CIAM
        // claims - which is the behaviour asserted here.
        assertEquals(null, accounts.list(
                authorisedOver(Set.of(AccessType.ACCOUNTS, AccessType.OWNER_NAME), MAIN), false)
                .getFirst().ownerName(),
                "the CIAM cannot grant access the consent never requested");
    }

    // ---- resource ids ---------------------------------------------------------------

    @Test
    @DisplayName("The same id on two calls")
    void resourceIdIsStable() {
        Consent consent = authorisedOver(Set.of(AccessType.ACCOUNTS), MAIN);

        assertEquals(accounts.list(consent, false).getFirst().resourceId(),
                accounts.list(consent, false).getFirst().resourceId());
    }

    @Test
    @DisplayName("The same IBAN under a new consent gets a new id")
    void resourceIdIsPerConsent() {
        String first = accounts.list(authorisedOver(Set.of(AccessType.ACCOUNTS), MAIN), false)
                .getFirst().resourceId();
        String second = accounts.list(authorisedOver(Set.of(AccessType.ACCOUNTS), MAIN), false)
                .getFirst().resourceId();

        assertFalse(first.equals(second),
                "a resource id is a handle into one consent, not a name for an account");
    }

    @Test
    @DisplayName("An account is addressable by its resourceId, and only under its own consent")
    void addressableByResourceId() {
        Consent consent = authorisedOver(Set.of(AccessType.ACCOUNTS), MAIN);
        Consent other = authorisedOver(Set.of(AccessType.ACCOUNTS), MAIN);
        String resourceId = accounts.list(consent, false).getFirst().resourceId();

        assertTrue(accounts.byResourceId(consent, resourceId, false).isPresent());
        assertTrue(accounts.byResourceId(other, resourceId, false).isEmpty(),
                "a resourceId of another consent addresses nothing");
    }

    @Test
    @DisplayName("A consent that is not valid serves nothing")
    void onlyValidConsentsServe() {
        ConsentService.Created created = consents.create(new ConsentRequest(TPP,
                AccountAccess.bankOffered(), true, LocalDate.of(2026, 12, 5), 4, false,
                "https://tpp.sandbox/cb", null, null));

        assertFalse(accounts.mayServe(created.consent(), LocalDate.of(2026, 9, 6)),
                "received, not yet valid");
    }

    @Test
    @DisplayName("A consent past its validUntil serves nothing")
    void expiredConsentServesNothing() {
        Consent consent = authorisedOver(Set.of(AccessType.ACCOUNTS), MAIN);

        assertTrue(accounts.mayServe(consent, LocalDate.of(2026, 12, 5)));
        assertFalse(accounts.mayServe(consent, LocalDate.of(2026, 12, 6)));
    }
}
