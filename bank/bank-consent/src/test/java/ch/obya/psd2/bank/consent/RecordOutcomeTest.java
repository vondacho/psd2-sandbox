package ch.obya.psd2.bank.consent;

import ch.obya.psd2.bank.consent.domain.*;
import ch.obya.psd2.bank.consent.appl.*;

import ch.obya.psd2.authorisation.ScaStatus;
import ch.obya.psd2.spec.OrganizationIdentifier;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Covers {@code docs/design/features/3-authenticate-and-approve-at-the-bank/
 * record-the-approved-authorisation.feature} — the customer-supplier edge from the CIAM
 * into consent management.
 */
class RecordOutcomeTest {

    private static final Instant NOW =
            LocalDate.of(2026, 9, 6).atStartOfDay(ZoneOffset.UTC).toInstant();
    private static final OrganizationIdentifier TPP =
            OrganizationIdentifier.parse("PSDDE-BAFIN-123456");
    private static final AccountReference MAIN =
            AccountReference.ofIban("DE23100100100123456789", "EUR");
    private static final AccountReference SAVINGS =
            AccountReference.ofIban("DE89370400440532013000", "EUR");

    private ConsentService serviceWith(SandboxLimits limits) {
        return new ConsentService(Clock.fixed(NOW, ZoneOffset.UTC), limits,
                () -> "123cons456", () -> "123auth567");
    }

    private ConsentService.Created createWith(ConsentService service, AccountAccess access) {
        return service.create(new ConsentRequest(TPP, access, true,
                LocalDate.of(2026, 12, 5), 4, false, "https://tpp.sandbox/cb", null, null));
    }

    private static AuthorisationOutcome outcome(Set<AccessType> types,
            AccountReference... accounts) {
        return new AuthorisationOutcome("anna.mueller", "chl-01J8",
                java.util.Arrays.stream(accounts)
                        .map(account -> new AuthorisationOutcome.ChosenAccount(
                                account, "EUR", types))
                        .toList());
    }

    @Test
    @DisplayName("Without a confirmation link: finalised and valid")
    void withoutConfirmation() {
        ConsentService service = serviceWith(SandboxLimits.defaults());
        ConsentService.Created created = createWith(service, AccountAccess.bankOffered());

        ConsentService.Recorded recorded = service.recordOutcome(created.consent().id(),
                created.authorisation().id(),
                outcome(Set.of(AccessType.ACCOUNTS, AccessType.BALANCES), MAIN));

        assertEquals(ScaStatus.FINALISED, recorded.authorisation().scaStatus());
        assertEquals(NOW, recorded.authorisation().finalisedAt());
        assertEquals(ConsentStatus.VALID, recorded.consent().status());
        assertEquals("anna.mueller", recorded.consent().psuId().orElseThrow());
    }

    @Test
    @DisplayName("With a confirmation link: unconfirmed, and the consent is not yet valid")
    void withConfirmation() {
        ConsentService service =
                serviceWith(SandboxLimits.defaults().withConfirmationRequired(true));
        ConsentService.Created created = createWith(service, AccountAccess.bankOffered());

        ConsentService.Recorded recorded = service.recordOutcome(created.consent().id(),
                created.authorisation().id(),
                outcome(Set.of(AccessType.ACCOUNTS, AccessType.BALANCES), MAIN));

        assertEquals(ScaStatus.UNCONFIRMED, recorded.authorisation().scaStatus());
        assertEquals(ConsentStatus.RECEIVED, recorded.consent().status(),
                "§7.6.4 reserves the last step for the TPP's confirmation call");
        assertEquals(1, recorded.consent().accessibleAccounts().size(),
                "the accounts are known even though the consent is not yet valid");
    }

    @Test
    @DisplayName("The TPP's confirmation call then finalises it and makes the consent valid")
    void confirmationFinalises() {
        ConsentService service =
                serviceWith(SandboxLimits.defaults().withConfirmationRequired(true));
        ConsentService.Created created = createWith(service, AccountAccess.bankOffered());
        service.recordOutcome(created.consent().id(), created.authorisation().id(),
                outcome(Set.of(AccessType.ACCOUNTS), MAIN));

        Authorisation confirmed = service.confirm(created.consent().id(),
                created.authorisation().id(), TPP);

        assertEquals(ScaStatus.FINALISED, confirmed.scaStatus());
        assertEquals(ConsentStatus.VALID,
                service.find(created.consent().id()).orElseThrow().status());
    }

    @Test
    @DisplayName("Two accounts are two accessible accounts")
    void twoAccounts() {
        ConsentService service = serviceWith(SandboxLimits.defaults());
        ConsentService.Created created = createWith(service, AccountAccess.bankOffered());

        ConsentService.Recorded recorded = service.recordOutcome(created.consent().id(),
                created.authorisation().id(),
                outcome(Set.of(AccessType.ACCOUNTS), MAIN, SAVINGS));

        assertEquals(2, recorded.consent().accessibleAccounts().size());
    }

    @Test
    @DisplayName("Each accessible account gets a fresh opaque resourceId, not derived from the IBAN")
    void opaqueResourceIds() {
        ConsentService service = serviceWith(SandboxLimits.defaults());
        ConsentService.Created created = createWith(service, AccountAccess.bankOffered());

        ConsentService.Recorded recorded = service.recordOutcome(created.consent().id(),
                created.authorisation().id(),
                outcome(Set.of(AccessType.ACCOUNTS), MAIN, SAVINGS));

        List<Consent.AccessibleAccount> accounts = recorded.consent().accessibleAccounts();
        for (Consent.AccessibleAccount account : accounts) {
            UUID parsed = UUID.fromString(account.resourceId()); // throws if not a UUID
            assertEquals(4, parsed.version(), "a random UUID, not a name-based one");
            assertFalse(account.resourceId().contains(account.account().iban()),
                    "a resource id must disclose nothing if it leaks");
        }
        assertFalse(accounts.get(0).resourceId().equals(accounts.get(1).resourceId()));
    }

    @Test
    @DisplayName("lastActionDate is today")
    void lastActionDateIsToday() {
        ConsentService service = serviceWith(SandboxLimits.defaults());
        ConsentService.Created created = createWith(service, AccountAccess.bankOffered());

        ConsentService.Recorded recorded = service.recordOutcome(created.consent().id(),
                created.authorisation().id(), outcome(Set.of(AccessType.ACCOUNTS), MAIN));

        assertEquals(LocalDate.of(2026, 9, 6), recorded.consent().lastActionDate());
    }

    // ---- access types never exceed the request ---------------------------------------

    @Test
    @DisplayName("Transactions are not recorded for an accounts+balances request")
    void transactionsNotRecordedWhenNotRequested() {
        ConsentService service = serviceWith(SandboxLimits.defaults());
        ConsentService.Created created = createWith(service, AccountAccess.bankOffered());

        ConsentService.Recorded recorded = service.recordOutcome(created.consent().id(),
                created.authorisation().id(),
                outcome(Set.of(AccessType.ACCOUNTS, AccessType.BALANCES), MAIN));

        assertFalse(recorded.consent().accessibleAccounts().getFirst().accessTypes()
                .contains(AccessType.TRANSACTIONS));
    }

    @Test
    @DisplayName("An outcome that claims transactions is trimmed, and the trim is reported")
    void claimedTransactionsAreTrimmed() {
        ConsentService service = serviceWith(SandboxLimits.defaults());
        ConsentService.Created created = createWith(service, AccountAccess.bankOffered());

        ConsentService.Recorded recorded = service.recordOutcome(created.consent().id(),
                created.authorisation().id(),
                outcome(Set.of(AccessType.ACCOUNTS, AccessType.BALANCES,
                        AccessType.TRANSACTIONS), MAIN));

        assertEquals(List.of(AccessType.ACCOUNTS, AccessType.BALANCES),
                recorded.consent().accessibleAccounts().getFirst().accessTypes());
        assertEquals(List.of("DE23100100100123456789:transactions"),
                recorded.trimmedAccessTypes(),
                "the discrepancy is reported so it can be logged as a warning");
    }

    @Test
    @DisplayName("An accounts-only request records accounts only")
    void accountsOnlyRequest() {
        ConsentService service = serviceWith(SandboxLimits.defaults());
        ConsentService.Created created = createWith(service, AccountAccess.accountsOnly());

        ConsentService.Recorded recorded = service.recordOutcome(created.consent().id(),
                created.authorisation().id(),
                outcome(Set.of(AccessType.ACCOUNTS, AccessType.BALANCES), MAIN));

        assertEquals(List.of(AccessType.ACCOUNTS),
                recorded.consent().accessibleAccounts().getFirst().accessTypes());
        assertTrue(recorded.trimmedAccessTypes().contains(
                "DE23100100100123456789:balances"));
    }

    @Test
    @DisplayName("A bank-offered request asks for accounts and balances, not transactions")
    void bankOfferedRequestedTypes() {
        assertEquals(Set.of(AccessType.ACCOUNTS, AccessType.BALANCES),
                AccountAccess.bankOffered().requestedTypes());
        assertEquals(Set.of(AccessType.ACCOUNTS),
                AccountAccess.accountsOnly().requestedTypes(),
                "an absent key is not the same as an empty array");
    }

    @Test
    @DisplayName("Data is served only once the consent is valid and to its creator alone")
    void servesDataOnlyWhenValid() {
        ConsentService service = serviceWith(SandboxLimits.defaults());
        ConsentService.Created created = createWith(service, AccountAccess.bankOffered());

        assertFalse(created.consent().servesDataTo(TPP), "not while it is only received");

        service.recordOutcome(created.consent().id(), created.authorisation().id(),
                outcome(Set.of(AccessType.ACCOUNTS), MAIN));

        assertTrue(created.consent().servesDataTo(TPP));
        assertFalse(created.consent().servesDataTo(
                OrganizationIdentifier.parse("PSDDE-BAFIN-654321")));
    }
}
