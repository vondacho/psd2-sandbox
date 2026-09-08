package ch.obya.psd2.bank.xs2a;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** The Bank's XS2A process: api.bank.sandbox. */
// The ledger adapter lives in bank-account-information, outside this package.
@SpringBootApplication(scanBasePackages = {"ch.obya.psd2.bank.xs2a",
        "ch.obya.psd2.bank.accounts"})
public class BankXs2aApplication {

    public static void main(String[] args) {
        SpringApplication.run(BankXs2aApplication.class, args);
    }
}
