package ch.obya.psd2.bank.accounts.adapter.out;

import ch.obya.psd2.bank.accounts.appl.*;
import ch.obya.psd2.bank.accounts.domain.*;

import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

/**
 * The anticorruption layer in code: the ledger's contract in, this context's types out.
 *
 * <p>Every ledger word stops here. {@code bookedBalance} becomes a
 * {@code CLOSING_BOOKED} balance, {@code availableBalance} becomes
 * {@code INTERIM_AVAILABLE}, {@code status ENABLED} becomes {@code open}, and
 * {@code paymentAccount} is dropped because a consent already decided that question.
 *
 * <p>The ledger is Microcks serving {@code contracts/bank-core-ledger.openapi.yaml}. A
 * real core banking system would replace this adapter and nothing else.
 */
@Component
public class MicrocksLedgerAccounts implements LedgerAccounts {

    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3)).build();
    private final ObjectMapper json = JsonMapper.builder().build();
    private final String baseUrl;
    private final String serviceToken;

    public MicrocksLedgerAccounts(
            @Value("${sandbox.ledger.base-url:http://localhost:8585/rest/Bank+core+ledger/1.0.0}")
            String baseUrl,
            @Value("${sandbox.ledger.service-token:ledger-service-token}") String serviceToken) {
        this.baseUrl = baseUrl;
        this.serviceToken = serviceToken;
    }

    @Override
    public Optional<LedgerAccount> byIban(String customerId, String iban, String currency) {
        // Two ledger reads make one XS2A resource: the customer's list carries the name,
        // the product and whether the account is still open; the account carries money.
        Map<?, ?> list = fetch("/customers/" + customerId + "/accounts");
        if (list == null) {
            return Optional.empty();
        }
        for (Object entry : (java.util.List<?>) list.get("accounts")) {
            Map<?, ?> account = (Map<?, ?>) entry;
            if (!iban.equals(account.get("iban"))) {
                continue;
            }
            Map<?, ?> balances = fetch("/accounts/" + iban + "/balances");
            return Optional.of(new LedgerAccount(
                    iban,
                    (String) account.get("currency"),
                    (String) account.get("productName"),
                    (String) account.get("productName"),
                    (String) account.get("accountType"),
                    "ENABLED".equals(account.get("status")),
                    (String) list.get("holderName"),
                    balances == null ? null : decimal(balances.get("bookedBalance")),
                    balances == null ? null : decimal(balances.get("availableBalance")),
                    balances == null ? null : instant(balances.get("asOf"))));
        }
        return Optional.empty();
    }

    private Map<?, ?> fetch(String path) {
        try {
            HttpResponse<String> response = http.send(
                    HttpRequest.newBuilder(URI.create(baseUrl + path))
                            // The ledger's contract declares a bearer service token.
                            // Sent unconditionally: the mock does not check it yet, but
                            // the day it does, nothing here changes.
                            .header("Authorization", "Bearer " + serviceToken)
                            .timeout(Duration.ofSeconds(3)).GET().build(),
                    HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                return null;   // ACCOUNT_UNKNOWN and the like stop here
            }
            return json.readValue(response.body(), Map.class);
        } catch (Exception unreachable) {
            return null;
        }
    }

    private static BigDecimal decimal(Object value) {
        return value == null ? null : new BigDecimal(value.toString());
    }

    private static Instant instant(Object value) {
        return value == null ? null : Instant.parse(value.toString());
    }
}
