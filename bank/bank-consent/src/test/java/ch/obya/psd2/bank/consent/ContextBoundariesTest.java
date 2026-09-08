package ch.obya.psd2.bank.consent;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

/**
 * The boundaries the context map draws, enforced where Maven cannot see them.
 *
 * <p>Maven's enforcer can ban a declared dependency; it cannot express "the consent id
 * must stay opaque to the OIDC-provider". These rules are the ones that would otherwise
 * be a comment nobody reads.
 */
class ContextBoundariesTest {

    private final JavaClasses context = new ClassFileImporter()
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
            .importPackages("ch.obya.psd2.bank.consent");

    @Test
    void doesNotDependOnPaymentInitiation() {
        noClasses().should().dependOnClassesThat()
                .resideInAPackage("ch.obya.psd2.bank.payment..")
                .because("consent management and payment initiation are a shared kernel: "
                        + "neither context can be downstream of the other")
                .check(context);
    }

    @Test
    void doesNotDependOnTokenIssuance() {
        noClasses().should().dependOnClassesThat()
                .resideInAPackage("ch.obya.psd2.oidc..")
                .because("the edge to token issuance is an anticorruption layer; the "
                        + "OIDC-provider is reached over the internal API, never by import")
                .check(context);
    }

    @Test
    void doesNotDependOnAWebFramework() {
        noClasses().should().dependOnClassesThat()
                .resideInAnyPackage("org.springframework..", "jakarta.servlet..")
                .because("the aggregates are the model; the REST adapter is a separate concern")
                .check(context);
    }
}
