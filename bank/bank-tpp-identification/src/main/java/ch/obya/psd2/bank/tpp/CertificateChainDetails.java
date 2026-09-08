package ch.obya.psd2.bank.tpp;

import java.time.Instant;
import java.util.List;

/** What the presented certificate says about itself, once parsed. */
public record CertificateChainDetails(
        String subjectDn,
        String issuerDn,
        String serial,
        String thumbprint,
        Instant notBefore,
        Instant notAfter,
        List<String> domains) {

    public CertificateChainDetails {
        domains = List.copyOf(domains);
    }
}
