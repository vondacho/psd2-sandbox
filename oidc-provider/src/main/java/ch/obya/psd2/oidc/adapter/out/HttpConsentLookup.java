package ch.obya.psd2.oidc.adapter.out;

import ch.obya.psd2.oidc.appl.*;
import ch.obya.psd2.oidc.domain.*;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

/**
 * The anticorruption layer to the Bank, in code.
 *
 * <p>Calls {@code GET /internal/consents/{id}?client_id=} and reads exactly three
 * fields. Anything else the Bank might send is ignored here, so the OIDC-provider cannot
 * start depending on the consent model even by accident.
 */
@Component
public class HttpConsentLookup implements ConsentLookup {

    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3)).build();
    private final ObjectMapper json = JsonMapper.builder().build();
    private final String baseUrl;

    public HttpConsentLookup(
            @Value("${sandbox.bank.internal-base-url:http://localhost:8081}") String baseUrl) {
        this.baseUrl = baseUrl;
    }

    @Override
    public ResourceStatus lookup(String resourceId, String clientId) throws LookupUnavailable {
        try {
            HttpResponse<String> response = http.send(HttpRequest.newBuilder(
                    URI.create(baseUrl + "/internal/consents/" + resourceId
                            + "?client_id=" + clientId))
                    .timeout(Duration.ofSeconds(3)).GET().build(),
                    HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() != 200) {
                throw new LookupUnavailable("the Bank answered " + response.statusCode());
            }
            Map<?, ?> body = json.readValue(response.body(), Map.class);
            return new ResourceStatus(
                    Boolean.TRUE.equals(body.get("exists")),
                    Boolean.TRUE.equals(body.get("ownedByClient")),
                    (String) body.get("status"));
        } catch (LookupUnavailable e) {
            throw e;
        } catch (Exception e) {
            // Not a refusal: the Bank could not answer. /authorize turns this into
            // temporarily_unavailable, and the TPP is expected to retry.
            throw new LookupUnavailable("consent management is unreachable: " + e.getMessage());
        }
    }
}
