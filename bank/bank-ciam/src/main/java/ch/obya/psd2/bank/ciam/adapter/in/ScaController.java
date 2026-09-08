package ch.obya.psd2.bank.ciam.adapter.in;

import ch.obya.psd2.bank.ciam.appl.*;
import ch.obya.psd2.bank.ciam.domain.*;

import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * What the registered device talks to: fetch the challenge, post the signature.
 *
 * <p>{@code GET /sca/challenges/{id}} deliberately returns what the PSU must see before
 * approving — "see what I am approving" — and never the dynamic-link hash's inputs in a
 * form the device could re-derive differently. The device signs what it is given.
 */
@RestController
public class ScaController {

    private final CiamService ciam;

    public ScaController(CiamService ciam) {
        this.ciam = ciam;
    }

    @GetMapping("/sca/challenges/{challengeId}")
    public ResponseEntity<Map<String, Object>> challenge(@PathVariable String challengeId) {
        return ciam.challenge(challengeId)
                .map(challenge -> ResponseEntity.ok(Map.<String, Object>of(
                        "challengeId", challenge.challengeId(),
                        "status", challenge.status().name().toLowerCase(java.util.Locale.ROOT),
                        "expiresAt", challenge.expiresAt().toString(),
                        // The three things the app shows and then signs over.
                        "tppName", challenge.dynamicLink().tppName(),
                        "summary", challenge.dynamicLink().summary(),
                        "message", challenge.messageToSign())))
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(Map.of("message", "no such challenge")));
    }

    /**
     * The device's answer. On approval the outcome is reported to consent management,
     * so this is where the two Bank processes meet.
     */
    @PostMapping("/sca/challenges/{challengeId}/response")
    public ResponseEntity<Map<String, Object>> respond(@PathVariable String challengeId,
            @RequestBody DeviceResponse response) {

        CiamService.Approval approval =
                ciam.respond(challengeId, response.deviceId(), response.signature());

        if (!approval.outcome().isApproved()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
                    "status", "refused",
                    "reason", approval.outcome().name()));
        }
        if (approval.recordingError() != null) {
            // The PSU approved but the Bank did not take it. Saying "approved" here
            // would leave the TPP waiting for a consent that never becomes valid.
            return ResponseEntity.status(HttpStatus.BAD_GATEWAY).body(Map.of(
                    "status", "approved-but-not-recorded",
                    "reason", approval.recordingError()));
        }
        return ResponseEntity.ok(Map.of(
                "status", "approved",
                "scaStatus", approval.scaStatus(),
                "consentStatus", approval.consentStatus()));
    }

    /** The PSU pressed deny on the device. */
    @PostMapping("/sca/challenges/{challengeId}/deny")
    public Map<String, Object> deny(@PathVariable String challengeId) {
        ciam.deny(challengeId);
        return Map.of("status", "denied");
    }

    public record DeviceResponse(String deviceId, String signature) {
    }
}
