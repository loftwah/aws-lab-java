package com.deanlofts.awslabjava.application.filter;

import com.deanlofts.awslabjava.application.config.AppProperties;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class RequestLoggingFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(RequestLoggingFilter.class);

    private final AppProperties appProperties;

    public RequestLoggingFilter(AppProperties appProperties) {
        this.appProperties = appProperties;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        Instant start = Instant.now();
        String traceId = UUID.randomUUID().toString();
        try {
            filterChain.doFilter(request, response);
        } finally {
            long duration = Duration.between(start, Instant.now()).toMillis();
            log.info(
                    "requestHandled traceId={} method={} path={} status={} durationMs={} deploymentTarget={}",
                    traceId,
                    request.getMethod(),
                    request.getRequestURI(),
                    response.getStatus(),
                    duration,
                    appProperties.getDeploymentTarget());
        }
    }
}
