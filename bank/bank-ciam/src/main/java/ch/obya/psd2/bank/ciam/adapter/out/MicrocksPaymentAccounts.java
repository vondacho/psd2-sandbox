package ch.obya.psd2.bank.ciam.adapter.out;

import ch.obya.psd2.bank.ciam.appl.PaymentAccountDirectory;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

/**
 * Reads the ledger's customer account list — the same Microcks mock the account
 * information context reads, through a different relationship.
 *
 * <p>Compare {@code MicrocksLedgerAccounts} in {@code bank-account-information}: that one
 * translates every field into its own vocabulary because it sits behind an anticorruption
 * layer. This one hands the ledger's shape straight through, because the design makes
 * this edge conformist. Copying the translation here would be the more "consistent" thing
 * to do and the wrong one — it would invent a model this context has no use for.
 *
 * <p>A ledger that cannot be reached yields an empty list rather than an error: the PSU
 * then sees "no accounts to share", which is a truthful screen, where a stack trace is
 * not.
 */
@Component
public class MicrocksPaymentAccounts implements PaymentAccountDirectory {

    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3)).build();
    private final ObjectMapper json = JsonMapper.builder().build();
    private final String baseUrl;
    private final String serviceToken;

    public MicrocksPaymentAccounts(
            @Value("${sandbox.ledger.base-url:http://localhost:8585/rest/Bank+core+ledger/1.0.0}")
            String baseUrl,
            @Value("${sandbox.ledger.service-token:ledger-service-token}") String serviceToken) {
        this.baseUrl = baseUrl;
        this.serviceToken = serviceToken;
    }

    @Override
    public List<LedgerAccount> accountsOf(String customerId) {
        try {
            HttpResponse<String> response = http.send(
                    HttpRequest.newBuilder(URI.create(
                                    baseUrl + "/customers/" + customerId + "/accounts"))
                            .header("Authorization", "Bearer " + serviceToken)
                            .timeout(Duration.ofSeconds(3)).GET().build(),
                    HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                return List.of();
            }
            Map<?, ?> body = json.readValue(response.body(), Map.class);
            return ((List<?>) body.get("accounts")).stream()
                    .map(Map.class::cast)
                    .map(account -> new LedgerAccount(
                            (String) account.get("iban"),
                            (String) account.get("currency"),
                            (String) account.get("productName"),
                            Boolean.TRUE.equals(account.get("paymentAccount"))))
                    .toList();
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
            return List.of();
        } catch (Exception unreachable) {
            return List.of();
        }
    }
}
