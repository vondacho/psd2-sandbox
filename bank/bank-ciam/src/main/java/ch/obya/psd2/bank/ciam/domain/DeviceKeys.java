package ch.obya.psd2.bank.ciam.domain;

import java.math.BigInteger;
import java.security.AlgorithmParameters;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.spec.ECGenParameterSpec;
import java.security.spec.ECParameterSpec;
import java.security.spec.ECPoint;
import java.security.spec.ECPublicKeySpec;
import java.util.Base64;

/**
 * Reads a device's public key from the JWK the app sends at enrolment.
 *
 * <p>"Only a P-256 public key in JWK form is accepted", so everything else is refused
 * here rather than stored and discovered later at signature time: a device whose key
 * cannot verify is worse than a device that was never enrolled.
 */
public final class DeviceKeys {

    private DeviceKeys() {
    }

    /**
     * @param kty must be {@code EC}, {@code crv} must be {@code P-256}
     * @throws IllegalArgumentException naming what was wrong, for the enrolment response
     */
    public static PublicKey fromJwk(String kty, String crv, String x, String y) {
        if (!"EC".equals(kty)) {
            throw new IllegalArgumentException("kty must be EC");
        }
        if (!"P-256".equals(crv)) {
            throw new IllegalArgumentException("crv must be P-256");
        }
        if (x == null || y == null) {
            throw new IllegalArgumentException("x and y are mandatory");
        }
        try {
            byte[] xs = Base64.getUrlDecoder().decode(x);
            byte[] ys = Base64.getUrlDecoder().decode(y);
            if (xs.length != 32 || ys.length != 32) {
                throw new IllegalArgumentException("x and y must be 32 bytes for P-256");
            }
            AlgorithmParameters parameters = AlgorithmParameters.getInstance("EC");
            parameters.init(new ECGenParameterSpec("secp256r1"));
            ECParameterSpec p256 = parameters.getParameterSpec(ECParameterSpec.class);
            ECPoint point = new ECPoint(new BigInteger(1, xs), new BigInteger(1, ys));
            return KeyFactory.getInstance("EC").generatePublic(
                    new ECPublicKeySpec(point, p256));
        } catch (IllegalArgumentException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalArgumentException("the JWK is not a valid P-256 key");
        }
    }
}
