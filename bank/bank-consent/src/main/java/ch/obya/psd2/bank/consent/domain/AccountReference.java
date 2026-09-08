package ch.obya.psd2.bank.consent.domain;

/**
 * How a TPP names an account (§14.17). Defined here because consent management owns it;
 * it is deliberately not hoisted into the shared primitives, since the CIAM sits across
 * a customer-supplier edge and keeps its own projection.
 */
public record AccountReference(
        String iban, String bban, String pan, String maskedPan, String msisdn,
        String currency) {

    public static AccountReference ofIban(String iban, String currency) {
        return new AccountReference(iban, null, null, null, null, currency);
    }
}
