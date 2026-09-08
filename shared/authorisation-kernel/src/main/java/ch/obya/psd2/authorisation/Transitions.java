package ch.obya.psd2.authorisation;

import java.util.Set;

/**
 * The forward-only transition rule both contexts share, parameterised by the terminal
 * set the owning context supplies.
 *
 * <p>Both {@code consent-management.ddm} and {@code payment-initiation.ddm} state the
 * same invariant — "the scaStatus moves forward only" — but disagree on which states end
 * the process. That disagreement is why this is a rule and not an aggregate.
 */
public record Transitions(Set<ScaStatus> terminals) {

    public Transitions {
        terminals = Set.copyOf(terminals);
    }

    public static Transitions forConsent() {
        return new Transitions(ScaStatus.consentTerminals());
    }

    public static Transitions forPayment() {
        return new Transitions(ScaStatus.paymentTerminals());
    }

    public boolean isTerminal(ScaStatus status) {
        return terminals.contains(status);
    }

    /** Forward-only: a terminal state admits nothing, and the ordinal may never decrease. */
    public boolean permits(ScaStatus from, ScaStatus to) {
        if (isTerminal(from)) {
            return false;
        }
        return to.ordinal() > from.ordinal();
    }

    public ScaStatus require(ScaStatus from, ScaStatus to) {
        if (!permits(from, to)) {
            throw new IllegalStateException(
                    "scaStatus may not move from " + from.wireName() + " to " + to.wireName());
        }
        return to;
    }
}
