package ch.obya.psd2.bank.ciam;

/**
 * The journey the CIAM runs, in order. The enum's declaration order is the permitted
 * order: identify, first factor, risk, account selection, challenge, outcome.
 */
public enum SessionStep {
    IDENTIFIED, FIRST_FACTOR_VERIFIED, RISK_ASSESSED, ACCOUNTS_SELECTED,
    CHALLENGE_ISSUED, APPROVED, REFUSED, COMPLETED
}
