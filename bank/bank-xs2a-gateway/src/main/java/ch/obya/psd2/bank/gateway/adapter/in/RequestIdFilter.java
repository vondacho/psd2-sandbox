package ch.obya.psd2.bank.gateway.adapter.in;


import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Echoes {@code X-Request-ID} on every answer, including refusals.
 *
 * <p>"The response carries the request's X-Request-ID" is asserted even on the error
 * paths, so this runs before the certificate filter and sets the header regardless of
 * what happens afterwards.
 */
@Order(Ordered.HIGHEST_PRECEDENCE)
public final class RequestIdFilter extends OncePerRequestFilter {

    public static final String HEADER = "X-Request-ID";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
            FilterChain chain) throws ServletException, IOException {
        String requestId = request.getHeader(HEADER);
        if (requestId != null && !requestId.isBlank()) {
            response.setHeader(HEADER, requestId);
        }
        chain.doFilter(request, response);
    }
}
