package ch.obya.psd2.pki;

import java.nio.file.Path;

/**
 * The operator's entry point.
 *
 * <pre>
 * generate [dir]   issue the CA, the seven fixture identities and a CRL (default target/pki)
 * </pre>
 *
 * <p>Errors print the message the feature specifies — {@code at least one PSD2 role is
 * required}, {@code unknown role BANK}, {@code no certificate for tpp-z} — and exit 1.
 */
public final class PkiCli {

    private PkiCli() {
    }

    public static void main(String[] args) {
        String command = args.length > 0 ? args[0] : "generate";
        try {
            if (!"generate".equals(command)) {
                throw new IllegalArgumentException("unknown command " + command);
            }
            Path out = Path.of(args.length > 1 ? args[1] : "target/pki");
            PkiFixtures.generateInto(out);
            System.out.println("wrote the sandbox PKI to " + out.toAbsolutePath());
            for (IssuanceRequest request : PkiFixtures.identities()) {
                System.out.printf("  %-20s %-6s %s%n", request.alias(), request.kind(),
                        request.roles());
            }
        } catch (IllegalArgumentException e) {
            System.err.println(e.getMessage());
            System.exit(1);
        } catch (Exception e) {
            System.err.println(command + " failed: " + e);
            System.exit(1);
        }
    }
}
