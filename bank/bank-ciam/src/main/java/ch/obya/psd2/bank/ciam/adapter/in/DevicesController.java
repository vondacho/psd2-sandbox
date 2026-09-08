package ch.obya.psd2.bank.ciam.adapter.in;

import ch.obya.psd2.bank.ciam.appl.*;
import ch.obya.psd2.bank.ciam.domain.*;

import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Device enrolment. A registered device is the possession element of SCA, so what is
 * stored here is what the SCA engine will later verify against.
 */
@RestController
public class DevicesController {

    private final CiamService ciam;

    public DevicesController(CiamService ciam) {
        this.ciam = ciam;
    }

    /**
     * "A newly registered device is pending until an existing SCA confirms it", so this
     * never returns an active device.
     */
    @PostMapping("/devices")
    public ResponseEntity<Map<String, Object>> register(@RequestBody Registration body) {
        try {
            RegisteredDevice device = ciam.registerDevice(body.psuId(), body.name(),
                    body.platform(), DeviceKeys.fromJwk(body.jwk().kty(), body.jwk().crv(),
                            body.jwk().x(), body.jwk().y()),
                    body.hardwareBacked() != null && body.hardwareBacked());

            return ResponseEntity.status(HttpStatus.CREATED).body(Map.of(
                    "deviceId", device.deviceId(),
                    "status", device.status().name().toLowerCase(java.util.Locale.ROOT)));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /** Confirmed by an existing SCA, which the sandbox exposes directly. */
    @PostMapping("/devices/{deviceId}/activate")
    public ResponseEntity<Map<String, Object>> activate(@PathVariable String deviceId) {
        return ciam.device(deviceId).map(device -> {
            device.activate();
            return ResponseEntity.ok(Map.<String, Object>of("deviceId", deviceId,
                    "status", device.status().name().toLowerCase(java.util.Locale.ROOT)));
        }).orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(Map.of("message", "no such device")));
    }

    @GetMapping("/devices")
    public Map<String, Object> list(@RequestParam("psu_id") String psuId) {
        List<Map<String, String>> devices = ciam.devicesOf(psuId).stream()
                .map(device -> Map.of(
                        "deviceId", device.deviceId(),
                        "name", device.name(),
                        "status", device.status().name().toLowerCase(java.util.Locale.ROOT)))
                .toList();
        return Map.of("devices", devices);
    }

    @DeleteMapping("/devices/{deviceId}")
    public ResponseEntity<Void> remove(@PathVariable String deviceId) {
        return ciam.device(deviceId).map(device -> {
            device.remove();
            return ResponseEntity.noContent().<Void>build();
        }).orElseGet(() -> ResponseEntity.notFound().build());
    }

    public record Registration(String psuId, String name, String platform,
            Boolean hardwareBacked, Jwk jwk) {
        public record Jwk(String kty, String crv, String x, String y) {
        }
    }
}
