package ch.obya.psd2.authorisation;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The shared kernel is only safe while it stays the genuine intersection of consent
 * management and payment initiation. Put an aggregate root or a persistence annotation
 * in here and both contexts become downstream of a jar, which is exactly what
 * psd2-access-to-account.ddd forbids.
 */
class KernelStaysSmallTest {

    private final JavaClasses kernel = new ClassFileImporter()
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
            .importPackages("ch.obya.psd2.authorisation");

    @Test
    void carriesNoPersistenceOrFrameworkDependency() {
        noClasses().should().dependOnClassesThat()
                .resideInAnyPackage("jakarta.persistence..", "org.springframework..")
                .because("the kernel is shared by two contexts; it must stay a plain model")
                .check(kernel);
    }

    @Test
    void staysSmallEnoughToBeAnIntersection() {
        assertTrue(kernel.size() <= 8,
                "the kernel holds " + kernel.size() + " types; above ~8 it has stopped being "
                        + "an intersection and started being a shared model");
    }
}
