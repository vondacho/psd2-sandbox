package ch.obya.psd2.bank.consent.appl;

import ch.obya.psd2.bank.consent.domain.*;

/**
 * The runtime-switchable parameters §13 says are worth exposing, and that scenarios
 * assert on directly ("Given the Bank runs with confirmationRequired true").
 *
 * <p>They are values rather than {@code @Value} fields so an admin endpoint can swap
 * them at run time without a restart, which an acceptance suite talking HTTP needs.
 */
public record SandboxLimits(
        int maxValidityDays,
        int maxFrequencyPerDay,
        boolean confirmationRequired) {

    /** Validity cap 180 days, frequency cap 4 per day, no confirmation link. */
    public static SandboxLimits defaults() {
        return new SandboxLimits(180, 4, false);
    }

    public SandboxLimits withConfirmationRequired(boolean required) {
        return new SandboxLimits(maxValidityDays, maxFrequencyPerDay, required);
    }
}
