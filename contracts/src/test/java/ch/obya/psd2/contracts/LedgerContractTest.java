package ch.obya.psd2.contracts;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.yaml.snakeyaml.Yaml;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Guards the ledger contract, because the contract <em>is</em> the mock.
 *
 * <p>Microcks pairs a request with a response by matching example names. A parameter
 * example with no response example of the same name dispatches to nothing, and a
 * response example no parameter selects is dead weight — neither is a YAML error, so
 * neither shows up until someone curls the mock and gets an empty body.
 */
class LedgerContractTest {

    private static final Path CONTRACT = Path.of("bank-core-ledger.openapi.yaml");

    @SuppressWarnings("unchecked")
    private Map<String, Object> contract() throws Exception {
        try (InputStream in = Files.newInputStream(CONTRACT)) {
            return new Yaml().load(in);
        }
    }

    @Test
    @DisplayName("Every parameter example has a response example of the same name")
    void examplesPairUp() throws Exception {
        List<String> unpaired = new ArrayList<>();

        for (Map.Entry<String, Object> path : paths(contract()).entrySet()) {
            for (Map.Entry<String, Object> operation
                    : ((Map<String, Object>) path.getValue()).entrySet()) {
                Map<String, Object> op = (Map<String, Object>) operation.getValue();

                Set<String> requestNames = new TreeSet<>();
                for (Object parameter : (List<Object>) op.getOrDefault("parameters", List.of())) {
                    Map<String, Object> examples =
                            (Map<String, Object>) ((Map<String, Object>) parameter)
                                    .get("examples");
                    if (examples != null) {
                        requestNames.addAll(examples.keySet());
                    }
                }
                Set<String> responseNames = responseExampleNames(op);

                for (String name : requestNames) {
                    if (!responseNames.contains(name)) {
                        unpaired.add(path.getKey() + " " + operation.getKey()
                                + ": request example '" + name + "' selects no response");
                    }
                }
                for (String name : responseNames) {
                    if (!requestNames.contains(name)) {
                        unpaired.add(path.getKey() + " " + operation.getKey()
                                + ": response example '" + name + "' is unreachable");
                    }
                }
            }
        }
        assertTrue(unpaired.isEmpty(), "Microcks dispatches by example name:\n  "
                + String.join("\n  ", unpaired));
    }

    @Test
    @DisplayName("The ledger speaks the ledger's language, not the interface's")
    void vocabularyStaysOnItsOwnSideOfTheAnticorruptionLayer() throws Exception {
        String text = Files.readString(CONTRACT);
        // The words the adapter is supposed to introduce. If they appear here, the
        // translation has been skipped and the ledger has started leaking XS2A.
        for (String xs2aTerm : List.of("resourceId", "closingBooked", "interimAvailable",
                "transactionId", "entryReference", "consentId", "bookingStatus")) {
            assertFalse(text.contains("\n" + " ".repeat(8) + xs2aTerm + ":")
                            || text.contains(xs2aTerm + ":"),
                    "'" + xs2aTerm + "' is XS2A vocabulary; the ledger must not use it, "
                            + "or the anticorruption layer has nothing left to translate");
        }
    }

    @Test
    @DisplayName("The fixtures are the ones the rest of the sandbox uses")
    void usesTheSharedFixtures() throws Exception {
        String text = Files.readString(CONTRACT);

        assertTrue(text.contains("DE23100100100123456789"), "Anna's Main Account");
        assertTrue(text.contains("DE89370400440532013000"), "Anna's Savings");
        assertTrue(text.contains("DE75512108001245126199"), "Ben's account");
        assertTrue(text.contains("1250.30"), "the closing balance of the fixtures");
    }

    @Test
    @DisplayName("A loan account is present and marked as not a payment account")
    void aNonPaymentAccountExists() throws Exception {
        String text = Files.readString(CONTRACT);

        assertTrue(text.contains("LOAN"), "the CIAM needs one to prove it offers no loan");
        assertTrue(text.contains("paymentAccount: false"));
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> paths(Map<String, Object> contract) {
        return (Map<String, Object>) contract.get("paths");
    }

    @SuppressWarnings("unchecked")
    private static Set<String> responseExampleNames(Map<String, Object> operation) {
        Set<String> names = new TreeSet<>();
        Map<String, Object> responses =
                (Map<String, Object>) operation.getOrDefault("responses", Map.of());
        for (Object response : responses.values()) {
            Map<String, Object> content =
                    (Map<String, Object>) ((Map<String, Object>) response).get("content");
            if (content == null) {
                continue;
            }
            for (Object media : content.values()) {
                Map<String, Object> examples =
                        (Map<String, Object>) ((Map<String, Object>) media).get("examples");
                if (examples != null) {
                    names.addAll(examples.keySet());
                }
            }
        }
        return names;
    }
}
