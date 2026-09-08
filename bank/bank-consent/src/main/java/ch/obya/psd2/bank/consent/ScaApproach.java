package ch.obya.psd2.bank.consent;

/**
 * The SCA approach announced on every resource (§4.6). The sandbox serves REDIRECT;
 * the other two exist so the model does not have to change when they are added.
 */
public enum ScaApproach {
    REDIRECT, DECOUPLED, EMBEDDED
}
