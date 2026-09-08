package ch.obya.psd2.bank.xs2a;

import ch.obya.psd2.bank.consent.ConsentService;
import ch.obya.psd2.bank.consent.SandboxLimits;
import java.time.Clock;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Wires consent management into the process. */
@Configuration
public class ConsentConfiguration {

    @Bean
    public SandboxLimits sandboxLimits() {
        return SandboxLimits.defaults();
    }

    @Bean
    public ConsentService consentService(Clock clock, SandboxLimits limits) {
        // Opaque, sequential handles. The fixtures name 123cons456 and 123auth567, so
        // the acceptance suite seeds those rather than relying on generation order.
        AtomicLong consents = new AtomicLong();
        AtomicLong authorisations = new AtomicLong();
        return new ConsentService(clock, limits,
                () -> "cons-" + consents.incrementAndGet(),
                () -> "auth-" + authorisations.incrementAndGet());
    }
}
