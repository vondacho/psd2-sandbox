package ch.obya.psd2.bank.ciam.domain;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.List;

/**
 * What the customer approves, and what the signature covers — EBA RTS art. 5.
 *
 * <p>The hash is SHA-256 over a canonical string, and "canonical" is the whole point: the
 * PSU's device and the Bank must derive byte-identical input from the same facts, or a
 * legitimate approval fails and a tampered one might pass.
 *
 * <pre>
 *   consentId | tppId | sorted "IBAN:CURRENCY" list, comma separated | validUntil
 *   123cons456|PSDDE-BAFIN-123456|DE23100100100123456789:EUR|2026-12-05
 * </pre>
 *
 * <p>Sorting is what makes the account order irrelevant, and pairing each IBAN with its
 * currency is what makes a multicurrency account two entries rather than one.
 *
 * @param subjectId the consent or payment being approved
 * @param tppName what the PSU is shown, e.g. {@code TPP App (TPP Fintech GmbH)}
 * @param summary the human sentence on the device, e.g. "accounts and balances of … until …"
 * @param hash lowercase hex SHA-256 of the canonical string
 */
public record DynamicLink(String subjectId, String tppName, String summary, String hash) {

    /** One account of the selection, as the link sees it. */
    public record SelectedAccount(String iban, String currency)
            implements Comparable<SelectedAccount> {

        /** Sorted by IBAN then currency, so [Savings, Main] and [Main, Savings] agree. */
        @Override
        public int compareTo(SelectedAccount other) {
            return Comparator.comparing(SelectedAccount::iban)
                    .thenComparing(SelectedAccount::currency)
                    .compare(this, other);
        }

        String canonical() {
            return iban + ":" + currency;
        }
    }

    /**
     * Builds the canonical string the hash is taken over.
     *
     * <p>IBANs are compared as written, with spaces removed, so the grouping a user
     * interface adds cannot change the hash.
     */
    public static String canonicalString(String subjectId, String tppId,
            List<SelectedAccount> selection, LocalDate validUntil) {
        String accounts = selection.stream()
                .map(account -> new SelectedAccount(
                        account.iban().replace(" ", ""), account.currency()))
                .sorted()
                .map(SelectedAccount::canonical)
                .distinct()
                .reduce((left, right) -> left + "," + right)
                .orElse("");
        return subjectId + "|" + tppId + "|" + accounts + "|" + validUntil;
    }

    public static String hashOf(String subjectId, String tppId,
            List<SelectedAccount> selection, LocalDate validUntil) {
        return sha256(canonicalString(subjectId, tppId, selection, validUntil));
    }

    /** The link for an account-information consent. */
    public static DynamicLink forConsent(String consentId, String tppId, String tppName,
            List<SelectedAccount> selection, LocalDate validUntil, String summary) {
        return new DynamicLink(consentId, tppName, summary,
                hashOf(consentId, tppId, selection, validUntil));
    }

    private static String sha256(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 is required", e);
        }
    }
}
