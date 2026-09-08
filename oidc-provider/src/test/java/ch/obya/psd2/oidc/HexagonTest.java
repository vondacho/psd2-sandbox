package ch.obya.psd2.oidc;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.library.Architectures.layeredArchitecture;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

/**
 * The hexagon of token issuance, and the two edges the context map draws around it.
 *
 * <p>With the layers in packages, the dependency direction can be asserted rather than
 * described: the domain knows nothing of the application layer, and neither knows
 * anything of an adapter.
 */
class HexagonTest {

    private final JavaClasses context = new ClassFileImporter()
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
            .importPackages("ch.obya.psd2.oidc");

    @Test
    @DisplayName("Dependencies point inwards: adapter -> appl -> domain")
    void dependenciesPointInwards() {
        layeredArchitecture().consideringOnlyDependenciesInLayers()
                // a context with no adapters yet is not a violation
                .withOptionalLayers(true)
                .layer("domain").definedBy("ch.obya.psd2.oidc.domain..")
                .layer("appl").definedBy("ch.obya.psd2.oidc.appl..")
                .layer("adapter").definedBy("ch.obya.psd2.oidc.adapter..")
                .whereLayer("adapter").mayNotBeAccessedByAnyLayer()
                .whereLayer("appl").mayOnlyBeAccessedByLayers("adapter")
                .whereLayer("domain").mayOnlyBeAccessedByLayers("appl", "adapter")
                .check(context);
    }

    @Test
    @DisplayName("The domain carries no framework")
    void domainIsPlainJava() {
        noClasses().that().resideInAPackage("ch.obya.psd2.oidc.domain..")
                .should().dependOnClassesThat()
                .resideInAnyPackage("org.springframework..", "jakarta..", "com.fasterxml..")
                .because("aggregates are the model; persistence and REST are adapters")
                .check(context);
    }

    @Test
    @DisplayName("The OIDC-provider never imports the Bank")
    void anticorruptionLayerHolds() {
        noClasses().should().dependOnClassesThat()
                .resideInAPackage("ch.obya.psd2.bank..")
                .because("both edges from the Bank are anticorruption layers; consent "
                        + "management is reached over the internal HTTP contract")
                .check(context);
    }
}
