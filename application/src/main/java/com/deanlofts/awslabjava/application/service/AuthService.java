package com.deanlofts.awslabjava.application.service;

import com.deanlofts.awslabjava.application.config.AppProperties;
import java.util.Objects;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);
    private static final String REDACTED = "<redacted>";

    private final AppProperties appProperties;

    public AuthService(AppProperties appProperties) {
        this.appProperties = appProperties;
    }

    public void assertAuthorized(String providedToken) {
        String expected = appProperties.getAuthToken();
        if (expected == null || expected.isBlank()) {
            log.warn("Auth token not configured; rejecting request");
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Auth token not configured");
        }
        if (!Objects.equals(expected, providedToken)) {
            log.warn("Unauthorized request denied: expected token {}, received {}", REDACTED, REDACTED);
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized");
        }
    }
}
