package ch.obya.psd2.bank.gateway;

import ch.obya.psd2.bank.tpp.TppIdentification;
import ch.obya.psd2.bank.tpp.TppIdentity;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.security.cert.X509Certificate;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Turns the certificate the TLS layer accepted into a {@link TppIdentity}, and refuses
 * the call when the certificate is sound but not usable.
 *
 * <p>By the time this runs the chain is already trusted — {@link ChainOnlyTrustManager}
 * saw to that during the handshake. What is left is semantic: is there a PSD2 statement,
 * is the identifier well formed, is the certificate inside its validity window, has it
 * been revoked or blocked. Each answers {@code 401} with a {@code tppMessages} body.
 *
 * <p>The identity is placed on the request as {@link #IDENTITY_ATTRIBUTE} so controllers
 * read it rather than re-parsing the certificate, and any client-supplied
 * {@code X-Client-Cert} header is ignored: the connection is the only source.
 */
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
public final class QwacFilter extends OncePerRequestFilter {

    /** Where the resolved identity is published for the rest of the request. */
    public static final String IDENTITY_ATTRIBUTE = "ch.obya.psd2.tppIdentity";

    private static final String SERVLET_CERTIFICATE_ATTRIBUTE =
            "jakarta.servlet.request.X509Certificate";

    private final TppIdentification identification;
    private final String protectedPathPrefix;

    public QwacFilter(TppIdentification identification, String protectedPathPrefix) {
        this.identification = identification;
        this.protectedPathPrefix = protectedPathPrefix;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        // The internal API and the admin endpoints are not TPP-facing and carry no QWAC.
        return !request.getRequestURI().startsWith(protectedPathPrefix);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
            FilterChain chain) throws ServletException, IOException {
        X509Certificate[] presented =
                (X509Certificate[]) request.getAttribute(SERVLET_CERTIFICATE_ATTRIBUTE);

        if (presented == null || presented.length == 0) {
            // Only reachable when a request bypassed the TLS port; the handshake would
            // otherwise have closed the connection.
            refuse(response, "CERTIFICATE_MISSING", "no client certificate on the connection");
            return;
        }

        TppIdentity identity = identification.identify(presented[0]);
        if (!identity.isIdentified()) {
            refuse(response, identity.messageCode().orElse("CERTIFICATE_INVALID"),
                    identity.reason());
            return;
        }

        request.setAttribute(IDENTITY_ATTRIBUTE, identity);
        chain.doFilter(request, response);
    }

    private void refuse(HttpServletResponse response, String code, String text)
            throws IOException {
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write(TppMessages.of(code, text).toJson());
    }
}
