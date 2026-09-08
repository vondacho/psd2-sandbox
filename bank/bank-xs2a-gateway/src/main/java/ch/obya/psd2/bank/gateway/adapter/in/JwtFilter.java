package ch.obya.psd2.bank.gateway.adapter.in;

import ch.obya.psd2.bank.tpp.domain.TppIdentity;
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
 * Checks the access token on every XS2A call, after the certificate and before the
 * controller looks at the consent.
 *
 * <p>That position is the specified order: certificate, signature, token, binding, scope,
 * consent. A controller that ran first would answer consent questions for a caller whose
 * token was never valid.
 */
@Order(Ordered.HIGHEST_PRECEDENCE + 20)
public final class JwtFilter extends OncePerRequestFilter {

    /** Where the validated consent id is published, so controllers do not re-parse. */
    public static final String CONSENT_ATTRIBUTE = "ch.obya.psd2.tokenConsentId";

    private static final String SERVLET_CERTIFICATE_ATTRIBUTE =
            "jakarta.servlet.request.X509Certificate";

    private final AccessTokenValidation tokens;
    private final String protectedPathPrefix;

    public JwtFilter(AccessTokenValidation tokens, String protectedPathPrefix) {
        this.tokens = tokens;
        this.protectedPathPrefix = protectedPathPrefix;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        if (!request.getRequestURI().startsWith(protectedPathPrefix)) {
            return true;
        }
        // Creating a consent is what obtains a token; it cannot require one.
        return request.getRequestURI().startsWith(protectedPathPrefix + "/consents");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
            FilterChain chain) throws ServletException, IOException {

        X509Certificate[] presented =
                (X509Certificate[]) request.getAttribute(SERVLET_CERTIFICATE_ATTRIBUTE);
        if (presented == null || presented.length == 0) {
            refuse(response, "CERTIFICATE_MISSING", "no client certificate");
            return;
        }
        TppIdentity identity =
                (TppIdentity) request.getAttribute(QwacFilter.IDENTITY_ATTRIBUTE);
        String clientId = identity == null || identity.organizationIdentifier() == null
                ? null : identity.organizationIdentifier().value();

        AccessTokenValidation.Result result = tokens.validate(
                request.getHeader("Authorization"), presented[0], clientId,
                request.getHeader("Consent-ID"));

        if (!result.accepted()) {
            refuse(response, result.code(), result.reason());
            return;
        }
        request.setAttribute(CONSENT_ATTRIBUTE, result.consentId());
        chain.doFilter(request, response);
    }

    private void refuse(HttpServletResponse response, String code, String reason)
            throws IOException {
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write(TppMessages.of(code, reason).toJson());
    }
}
