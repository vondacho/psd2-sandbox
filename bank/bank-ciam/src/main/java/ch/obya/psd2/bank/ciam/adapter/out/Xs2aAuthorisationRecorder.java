package ch.obya.psd2.bank.ciam.adapter.out;

import ch.obya.psd2.bank.ciam.appl.*;
import ch.obya.psd2.bank.ciam.domain.*;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;
import org.springframework.stereotype.Component;

/**
 * Reports an approved authorisation to consent management over §7.7's internal API.
 *
 * <p>{@code POST /internal/consents/{id}/authorisations/{authId}} — a different process,
 * reached over HTTP, which is what keeps the two contexts from sharing a model.
 */
@Component
public class Xs2aAuthorisationRecorder implements AuthorisationRecorder {

    private final HttpClient http;
    // Boot 4 ships Jackson 3, whose mapper lives under tools.jackson.
    private final ObjectMapper json = JsonMapper.builder().build();
    private final String baseUrl;

    public Xs2aAuthorisationRecorder(
            @org.springframework.beans.factory.annotation.Value(
                    "${sandbox.bank.internal-base-url:http://localhost:8081}") String baseUrl) {
        this.baseUrl = baseUrl;
        this.http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(3))
                .sslContext(TrustTheSandbox.context())
                .build();
    }

    @Override
    public Recorded record(String consentId, String authorisationId, String psuId,
            String challengeId, List<DynamicLink.SelectedAccount> accounts)
            throws RecordingFailed {
        try {
            String body = json.writeValueAsString(Map.of(
                    "psuId", psuId,
                    "challengeId", challengeId,
                    "accounts", accounts.stream()
                            .map(account -> Map.of(
                                    "iban", account.iban(),
                                    "currency", account.currency(),
                                    // The consent decides what these become; the CIAM
                                    // proposes the access the consent screen offered.
                                    "accessTypes", List.of("accounts", "balances")))
                            .collect(Collectors.toList())));

            HttpResponse<String> response = http.send(HttpRequest.newBuilder(
                    URI.create(baseUrl + "/internal/consents/" + consentId
                            + "/authorisations/" + authorisationId))
                    .header("Content-Type", "application/json")
                    .timeout(Duration.ofSeconds(3))
                    .POST(HttpRequest.BodyPublishers.ofString(body)).build(),
                    HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() / 100 != 2) {
                throw new RecordingFailed("the Bank answered " + response.statusCode());
            }
            Map<?, ?> answer = json.readValue(response.body(), Map.class);
            return new Recorded((String) answer.get("scaStatus"),
                    (String) answer.get("consentStatus"));
        } catch (RecordingFailed e) {
            throw e;
        } catch (Exception e) {
            throw new RecordingFailed("consent management is unreachable: " + e.getMessage());
        }
    }
}
