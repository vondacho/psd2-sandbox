package ch.obya.psd2.bank.ciam;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.library.Architectures.layeredArchitecture;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

/**
 * The hexagon of customer identity and SCA, and the two edges the context map draws around it.
 *
 * <p>With the layers in packages, the dependency direction can be asserted rather than
 * described: the domain knows nothing of the application layer, and neither knows
 * anything of an adapter.
 */
class HexagonTest {

    private final JavaClasses context = new ClassFileImporter()
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
            .importPackages("ch.obya.psd2.bank.ciam");

    @Test
    @DisplayName("Dependencies point inwards: adapter -> appl -> domain")
    void dependenciesPointInwards() {
        layeredArchitecture().consideringOnlyDependenciesInLayers()
                // a context with no adapters yet is not a violation
                .withOptionalLayers(true)
                .layer("domain").definedBy("ch.obya.psd2.bank.ciam.domain..")
                .layer("appl").definedBy("ch.obya.psd2.bank.ciam.appl..")
                .layer("adapter").definedBy("ch.obya.psd2.bank.ciam.adapter..")
                .whereLayer("adapter").mayNotBeAccessedByAnyLayer()
                .whereLayer("appl").mayOnlyBeAccessedByLayers("adapter")
                .whereLayer("domain").mayOnlyBeAccessedByLayers("appl", "adapter")
                .check(context);
    }

    @Test
    @DisplayName("The domain carries no framework")
    void domainIsPlainJava() {
        noClasses().that().resideInAPackage("ch.obya.psd2.bank.ciam.domain..")
                .should().dependOnClassesThat()
                .resideInAnyPackage("org.springframework..", "jakarta..", "com.fasterxml..")
                .because("aggregates are the model; persistence and REST are adapters")
                .check(context);
    }

    @Test
    @DisplayName("The CIAM keeps its own account projection")
    void doesNotImportTheConsentModel() {
        noClasses().should().dependOnClassesThat()
                .resideInAPackage("ch.obya.psd2.bank.consent..")
                .because("the edge from consent management is customer-supplier, not a "
                        + "shared kernel: the CIAM speaks the consent's language over the "
                        + "internal API and keeps its own SelectedAccount")
                .check(context);
    }
}
