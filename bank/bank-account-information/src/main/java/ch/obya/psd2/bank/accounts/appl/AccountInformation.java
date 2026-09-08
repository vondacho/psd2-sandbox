package ch.obya.psd2.bank.accounts.appl;

import ch.obya.psd2.bank.accounts.domain.*;
import ch.obya.psd2.bank.consent.domain.AccessType;
import ch.obya.psd2.bank.consent.domain.Consent;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Serves the accounts of one consent, read from the ledger at call time.
 *
 * <p>Two facts decide every answer, and they are checked in this order.
 *
 * <p><strong>The consent decides which accounts exist</strong> for this TPP. An account
 * the PSU did not tick is not merely hidden — it has no {@code resourceId} under this
 * consent and so cannot be addressed at all.
 *
 * <p><strong>The ledger decides what they currently say.</strong> "The list reflects the
 * ledger at call time, filtered by the consent": a renamed account shows its new name, an
 * account closed since the consent disappears, and an account opened since is not listed
 * because the consent never granted it.
 */
public final class AccountInformation {

    private final LedgerAccounts ledger;

    public AccountInformation(LedgerAccounts ledger) {
        this.ledger = ledger;
    }

    /**
     * The account list of {@code consent}.
     *
     * @param withBalance whether the caller asked for balances; they are served only if
     *     the consent also granted the {@code balances} access type
     */
    public List<AccountResource> list(Consent consent, boolean withBalance) {
        List<AccountResource> resources = new ArrayList<>();
        for (Consent.AccessibleAccount accessible : consent.accessibleAccounts()) {
            project(consent, accessible, withBalance).ifPresent(resources::add);
        }
        return resources;
    }

    /** One account of the consent, by its resource id. */
    public Optional<AccountResource> byResourceId(Consent consent, String resourceId,
            boolean withBalance) {
        return consent.accessibleAccounts().stream()
                .filter(accessible -> accessible.resourceId().equals(resourceId))
                .findFirst()
                .flatMap(accessible -> project(consent, accessible, withBalance));
    }

    private Optional<AccountResource> project(Consent consent,
            Consent.AccessibleAccount accessible, boolean withBalance) {

        String customerId = consent.psuId().orElse(null);
        if (customerId == null) {
            return Optional.empty();   // no PSU means no authorised consent
        }
        return ledger.byIban(customerId, accessible.account().iban(), accessible.currency())
                // An account closed at the bank since the consent is no longer served.
                .filter(LedgerAccounts.LedgerAccount::open)
                .map(account -> {
                    // Balances need both: the caller asking, and the consent granting.
                    boolean balances = withBalance
                            && accessible.accessTypes().contains(AccessType.BALANCES);
                    return new AccountResource(
                            accessible.resourceId(),
                            account.iban(),
                            account.currency(),
                            account.name(),
                            account.product(),
                            account.accountType(),
                            accessible.accessTypes().contains(AccessType.OWNER_NAME)
                                    ? account.holderName() : null,
                            balances ? account.asBalances() : List.of());
                });
    }

    /** True while the consent may serve data to this caller on this day. */
    public boolean mayServe(Consent consent, LocalDate today) {
        return consent.status() == ch.obya.psd2.bank.consent.domain.ConsentStatus.VALID
                && !consent.validUntil().isBefore(today);
    }
}
