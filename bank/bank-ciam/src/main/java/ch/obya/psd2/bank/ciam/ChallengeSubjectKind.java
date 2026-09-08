package ch.obya.psd2.bank.ciam;

/** What is being approved. The CIAM approves a payment the same way it approves a consent. */
public enum ChallengeSubjectKind {
    AIS_CONSENT, PIS_PAYMENT, PIIS_CONSENT, DEVICE_ENROLMENT
}
