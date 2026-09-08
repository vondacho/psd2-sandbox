package ch.obya.psd2.bank.accounts.domain;

import java.math.BigDecimal;
import java.time.Instant;

/** One typed balance of an account resource. */
public record Balance(BalanceType type, String currency, BigDecimal amount,
        Instant lastChangeDateTime) {
}
