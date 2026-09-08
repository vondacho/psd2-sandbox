package ch.obya.psd2.bank.consent.domain;

/** What a consent may grant on one account. */
public enum AccessType {
    ACCOUNTS("accounts"),
    BALANCES("balances"),
    TRANSACTIONS("transactions"),
    OWNER_NAME("ownerName");

    private final String wireName;

    AccessType(String wireName) {
        this.wireName = wireName;
    }

    public String wireName() {
        return wireName;
    }
}
