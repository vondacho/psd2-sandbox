package ch.obya.psd2.oidc;

import ch.obya.psd2.oidc.domain.*;
import ch.obya.psd2.oidc.appl.*;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * The anticorruption layer, asserted rather than described.
 *
 * <p>The context map says the OIDC-provider "must never learn the consent model beyond
 * existence and status", and the feature says it "never receives the access object or
 * the PSU". Both are structural claims, so they can be checked structurally.
 */
class AnticorruptionLayerTest {

    private final JavaClasses context = new ClassFileImporter()
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
            .importPackages("ch.obya.psd2.oidc");

    @Test
    @DisplayName("The OIDC-provider never receives the access object or the PSU")
    void theInternalContractCarriesThreeFieldsAndNoMore() {
        List<String> fields = Arrays.stream(ResourceStatus.class.getRecordComponents())
                .map(component -> component.getName())
                .toList();

        assertEquals(List.of("exists", "ownedByClient", "status"), fields,
                "widening this record leaks the Bank's model across a domain boundary; "
                        + "there must be no access, psuId, validUntil or accounts field");
    }

    @Test
    void keepsTheResourceIdOpaque() {
        // A String, not a ConsentId: "a thin layer keeps AIS:<consentId> an opaque handle".
        assertEquals(String.class,
                Arrays.stream(ScopeTarget.class.getRecordComponents())
                        .filter(component -> component.getName().equals("resourceId"))
                        .findFirst().orElseThrow().getType());
    }
}
