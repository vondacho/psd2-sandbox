package ch.obya.psd2.pki;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Covers the scenario "openssl shows the QcStatement".
 *
 * <p>The scenario as generated asserts that {@code openssl x509 -text} output contains
 * both {@code qcStatements} and {@code 0.4.0.19495.2}. Only the first is true of
 * OpenSSL 3.x: it prints the extension name but dumps the body as opaque bytes rather
 * than decoding the OIDs. {@code -certopt ext_parse} is what decodes it. This test pins
 * both facts so the example map can be corrected against measured behaviour.
 */
class OpensslReadsTheStatementTest {

    @Test
    @DisplayName("openssl shows the QcStatement — needs -certopt ext_parse for the OID")
    void opensslDecodesTheStatement(@TempDir Path dir) throws Exception {
        Assumptions.assumeTrue(onPath("openssl"), "openssl not installed");

        SandboxCa ca = SandboxCa.create(PkiFixtures.TODAY);
        Path pem = dir.resolve("tpp.pem");
        Files.writeString(pem, toPem(ca.issue(PkiFixtures.identities().getFirst())
                .certificate().getEncoded()));

        String plain = run(List.of("openssl", "x509", "-in", pem.toString(), "-noout", "-text"));
        String parsed = run(List.of("openssl", "x509", "-in", pem.toString(), "-noout", "-text",
                "-certopt", "ext_parse"));

        assertTrue(plain.contains("qcStatements"), "plain -text names the extension");
        assertFalse(plain.contains("0.4.0.19495.2"),
                "OpenSSL 3.x does NOT decode the statement id under plain -text; "
                        + "the example map's scenario assumes it does");
        assertTrue(parsed.contains("0.4.0.19495.2"), "-certopt ext_parse decodes the statement id");
        assertTrue(parsed.contains("PSP_AI") && parsed.contains("PSP_PI"), "roles decode");
        assertTrue(parsed.contains("BaFin") && parsed.contains("DE-BAFIN"), "NCA decodes");
    }

    private static boolean onPath(String command) {
        return java.util.Arrays.stream(System.getenv("PATH").split(java.io.File.pathSeparator))
                .anyMatch(entry -> Files.isExecutable(Path.of(entry, command)));
    }

    private static String run(List<String> command) throws Exception {
        Process process = new ProcessBuilder(command).redirectErrorStream(true).start();
        String output = new String(process.getInputStream().readAllBytes());
        process.waitFor();
        return output;
    }

    private static String toPem(byte[] der) {
        return "-----BEGIN CERTIFICATE-----\n"
                + java.util.Base64.getMimeEncoder(64, new byte[] {'\n'}).encodeToString(der)
                + "\n-----END CERTIFICATE-----\n";
    }
}
