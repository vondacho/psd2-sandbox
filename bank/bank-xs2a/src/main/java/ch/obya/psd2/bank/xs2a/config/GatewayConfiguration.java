package ch.obya.psd2.bank.xs2a.config;

import ch.obya.psd2.bank.xs2a.adapter.in.*;

import ch.obya.psd2.bank.gateway.adapter.in.QwacFilter;
import ch.obya.psd2.bank.gateway.adapter.in.RequestIdFilter;
import ch.obya.psd2.bank.tpp.appl.TppIdentification;
import java.time.Clock;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Mounts the gateway filters on the TPP-facing paths. */
@Configuration
public class GatewayConfiguration {

    /** Everything under here needs a QWAC; /internal and /admin do not. */
    public static final String XS2A_PREFIX = "/psd2/v1";

    private final Set<String> revokedSerials = ConcurrentHashMap.newKeySet();
    private final Set<String> blockedSerials = ConcurrentHashMap.newKeySet();

    @Bean
    public Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    public TppIdentification tppIdentification(Clock clock) {
        return new TppIdentification(clock, revokedSerials::contains, blockedSerials::contains);
    }

    /** Exposed so the sandbox admin endpoint can revoke or block a serial at run time. */
    @Bean
    public CertificateStatusRegistry certificateStatusRegistry() {
        return new CertificateStatusRegistry(revokedSerials, blockedSerials);
    }

    @Bean
    public FilterRegistrationBean<RequestIdFilter> requestIdFilter() {
        FilterRegistrationBean<RequestIdFilter> registration =
                new FilterRegistrationBean<>(new RequestIdFilter());
        registration.addUrlPatterns("/*");
        registration.setOrder(1);
        return registration;
    }

    @Bean
    public FilterRegistrationBean<QwacFilter> qwacFilter(TppIdentification identification) {
        FilterRegistrationBean<QwacFilter> registration = new FilterRegistrationBean<>(
                new QwacFilter(identification, XS2A_PREFIX));
        registration.addUrlPatterns("/*");
        registration.setOrder(2);
        return registration;
    }

    /** Lets the sandbox mark a certificate revoked or blocked without a restart. */
    public record CertificateStatusRegistry(Set<String> revoked, Set<String> blocked) {
        public void revoke(String serial) {
            revoked.add(serial.toUpperCase(java.util.Locale.ROOT));
        }

        public void block(String serial) {
            blocked.add(serial.toUpperCase(java.util.Locale.ROOT));
        }

        public void clear() {
            revoked.clear();
            blocked.clear();
        }
    }
}
