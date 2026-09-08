package ch.obya.psd2.bank.ciam.config;

import ch.obya.psd2.bank.ciam.adapter.in.*;
import ch.obya.psd2.bank.ciam.appl.*;
import ch.obya.psd2.bank.ciam.domain.*;

import java.time.Clock;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Wires the CIAM and seeds the sandbox's PSUs. */
@Configuration
public class CiamConfiguration {

    @Bean
    public Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    public CiamService ciamService(Clock clock, AuthorisationRecorder recorder) {
        AtomicLong challenges = new AtomicLong();
        AtomicLong devices = new AtomicLong();
        CiamService ciam = new CiamService(clock,
                () -> "chl-%04d".formatted(challenges.incrementAndGet()),
                () -> "dev-%04d".formatted(devices.incrementAndGet()),
                recorder);

        // The fixtures of docs/design/examplemap/README.md, so the acceptance suite and
        // a person poking at the sandbox meet the same Anna.
        ciam.register(new PsuIdentity("anna.mueller", "Anna Müller", "correct horse"));
        ciam.register(new PsuIdentity("ben.weber", "Ben Weber", "hunter2 please"));
        return ciam;
    }
}
