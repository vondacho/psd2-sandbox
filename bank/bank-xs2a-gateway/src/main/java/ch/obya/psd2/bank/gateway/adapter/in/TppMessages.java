package ch.obya.psd2.bank.gateway.adapter.in;


import java.util.List;

/**
 * The §4.13 error body: {@code {tppMessages: [{category, code, text, path}]}}.
 *
 * <p>One shape for every refusal in the interface, which is why it lives in the gateway
 * library rather than in any one context: 526 {@code @error} scenarios across the suite
 * assert on it.
 */
public record TppMessages(List<TppMessage> tppMessages) {

    public static TppMessages of(String code, String text) {
        return new TppMessages(List.of(new TppMessage("ERROR", code, text, null)));
    }

    public static TppMessages of(String code, String text, String path) {
        return new TppMessages(List.of(new TppMessage("ERROR", code, text, path)));
    }

    /**
     * Renders the body without a JSON library.
     *
     * <p>The gateway filters run before Spring MVC's message converters, and this module
     * is a library used by more than one process. Hand-writing four fields keeps it free
     * of a Jackson version — Boot 4 defaults to Jackson 3 ({@code tools.jackson}) while
     * plenty of code still expects Jackson 2, and a filter is the wrong place to care.
     */
    public String toJson() {
        StringBuilder json = new StringBuilder("{\"tppMessages\":[");
        for (int i = 0; i < tppMessages.size(); i++) {
            TppMessage message = tppMessages.get(i);
            if (i > 0) {
                json.append(',');
            }
            json.append("{\"category\":").append(quote(message.category()))
                    .append(",\"code\":").append(quote(message.code()))
                    .append(",\"text\":").append(quote(message.text()));
            if (message.path() != null) {
                json.append(",\"path\":").append(quote(message.path()));
            }
            json.append('}');
        }
        return json.append("]}").toString();
    }

    private static String quote(String value) {
        if (value == null) {
            return "null";
        }
        StringBuilder out = new StringBuilder("\"");
        for (int i = 0; i < value.length(); i++) {
            char c = value.charAt(i);
            switch (c) {
                case '"' -> out.append("\\\"");
                case '\\' -> out.append("\\\\");
                case '\n' -> out.append("\\n");
                case '\r' -> out.append("\\r");
                case '\t' -> out.append("\\t");
                default -> {
                    if (c < 0x20) {
                        out.append(String.format("\\u%04x", (int) c));
                    } else {
                        out.append(c);
                    }
                }
            }
        }
        return out.append('"').toString();
    }

    /**
     * @param category {@code ERROR} or {@code WARNING}
     * @param code the message code, e.g. {@code CERTIFICATE_REVOKED}
     * @param path the offending field for a {@code FORMAT_ERROR}; omitted otherwise
     */
    public record TppMessage(String category, String code, String text, String path) {
    }
}
