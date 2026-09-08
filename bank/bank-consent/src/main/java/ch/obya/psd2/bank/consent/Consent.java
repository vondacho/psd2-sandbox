package ch.obya.psd2.bank.consent;

import ch.obya.psd2.spec.OrganizationIdentifier;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * A TPP's request to access a PSU's account information, from received until valid,
 * rejected, expired, revoked or terminated.
 *
 * <p>The consistency boundary for access rights and access frequency, so the accessible
 * accounts and the usage counters live inside it rather than beside it.
 */
public final class Consent {

    private final ConsentId id;
    private final OrganizationIdentifier tppId;
    private final AccountAccess access;
    private final boolean recurringIndicator;
    private final int frequencyPerDay;
    private final boolean combinedServiceIndicator;
    private final Instant createdAt;
    private final String tppRedirectUri;
    private final String tppNokRedirectUri;
    private final ScaApproach scaApproach;
    private final LocalDate validUntil;

    private ConsentStatus status;
    private String psuId;
    private LocalDate lastActionDate;
    private final List<AccessibleAccount> accessibleAccounts = new ArrayList<>();
    private final Map<UsageKey, Integer> usageCounters = new LinkedHashMap<>();

    Consent(ConsentId id, OrganizationIdentifier tppId, AccountAccess access,
            boolean recurringIndicator, LocalDate validUntil, int frequencyPerDay,
            boolean combinedServiceIndicator, String tppRedirectUri, String tppNokRedirectUri,
            ScaApproach scaApproach, String psuId, Instant createdAt) {
        this.id = id;
        this.tppId = tppId;
        this.access = access;
        this.recurringIndicator = recurringIndicator;
        this.validUntil = validUntil;
        this.frequencyPerDay = frequencyPerDay;
        this.combinedServiceIndicator = combinedServiceIndicator;
        this.tppRedirectUri = tppRedirectUri;
        this.tppNokRedirectUri = tppNokRedirectUri;
        this.scaApproach = scaApproach;
        this.psuId = psuId;
        this.createdAt = createdAt;
        this.status = ConsentStatus.RECEIVED;
        this.lastActionDate = LocalDate.ofInstant(createdAt, java.time.ZoneOffset.UTC);
    }

    public ConsentId id() {
        return id;
    }

    public OrganizationIdentifier tppId() {
        return tppId;
    }

    public AccountAccess access() {
        return access;
    }

    public ConsentStatus status() {
        return status;
    }

    public boolean recurringIndicator() {
        return recurringIndicator;
    }

    public LocalDate validUntil() {
        return validUntil;
    }

    public int frequencyPerDay() {
        return frequencyPerDay;
    }

    public boolean combinedServiceIndicator() {
        return combinedServiceIndicator;
    }

    public Instant createdAt() {
        return createdAt;
    }

    public LocalDate lastActionDate() {
        return lastActionDate;
    }

    public String tppRedirectUri() {
        return tppRedirectUri;
    }

    public String tppNokRedirectUri() {
        return tppNokRedirectUri;
    }

    public ScaApproach scaApproach() {
        return scaApproach;
    }

    /** Empty until the PSU logs in, unless a PSU-ID header named them at creation. */
    public Optional<String> psuId() {
        return Optional.ofNullable(psuId);
    }

    public List<AccessibleAccount> accessibleAccounts() {
        return List.copyOf(accessibleAccounts);
    }

    void identifyPsu(String psuId) {
        this.psuId = psuId;
    }

    /**
     * Records what the PSU chose at the Bank, and makes the consent valid.
     *
     * <p>"An accessible account may only carry access types that the requested access
     * asked for", and "a consent becomes valid only after every mandated authorisation
     * is finalised" — so this is called by the authorisation, not by the TPP.
     */
    void grantAccessTo(Collection<AccessibleAccount> chosen, LocalDate on) {
        recordAccessibleAccounts(chosen, on);
        status = ConsentStatus.VALID;
    }

    /**
     * Records what the PSU chose without making the consent valid.
     *
     * <p>Used when a confirmation link was returned: the accounts are known, but §7.6.4
     * reserves the last step for the TPP, so the consent stays {@code received} until the
     * confirmation call arrives.
     */
    void recordAccessibleAccounts(Collection<AccessibleAccount> chosen, LocalDate on) {
        accessibleAccounts.clear();
        accessibleAccounts.addAll(chosen);
        lastActionDate = on;
    }

    void moveTo(ConsentStatus next, LocalDate on) {
        if (status.isFinal()) {
            throw new IllegalStateException(
                    "consent is already " + status.wireName() + " and cannot become "
                            + next.wireName());
        }
        status = next;
        lastActionDate = on;
    }

    /** True while account data may be served to {@code caller}. */
    public boolean servesDataTo(OrganizationIdentifier caller) {
        return status == ConsentStatus.VALID && tppId.equals(caller);
    }

    /**
     * Counts one access of {@code resourceId} on {@code day} when the PSU is absent.
     *
     * @return false when the counter has already reached {@link #frequencyPerDay()},
     *     which the interface answers with {@code 429 ACCESS_EXCEEDED}
     */
    public boolean countAccess(String resourceId, LocalDate day, boolean psuPresent) {
        if (psuPresent) {
            return true; // §6: a call with the PSU present is not counted
        }
        UsageKey key = new UsageKey(resourceId, day);
        int used = usageCounters.getOrDefault(key, 0);
        if (used >= frequencyPerDay) {
            return false;
        }
        usageCounters.put(key, used + 1);
        return true;
    }

    public int usageOf(String resourceId, LocalDate day) {
        return usageCounters.getOrDefault(new UsageKey(resourceId, day), 0);
    }

    /** One account the PSU made accessible, with the access types it carries. */
    public record AccessibleAccount(String resourceId, AccountReference account,
            String currency, List<AccessType> accessTypes) {
        public AccessibleAccount {
            accessTypes = List.copyOf(accessTypes);
        }
    }

    private record UsageKey(String resourceId, LocalDate day) {
    }
}
