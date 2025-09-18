package com.deanlofts.awslabjava.application.service;

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

  private final AuthTokenProvider authTokenProvider;

  public AuthService(AuthTokenProvider authTokenProvider) {
    this.authTokenProvider = authTokenProvider;
  }

  public void assertAuthorized(String providedToken) {
    if (providedToken == null || providedToken.isBlank()) {
      log.warn("Unauthorized request denied: missing token");
      throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized");
    }

    String expected;
    try {
      expected = authTokenProvider.requiredToken();
    } catch (IllegalStateException ex) {
      log.error("Auth token not available", ex);
      throw new ResponseStatusException(
          HttpStatus.SERVICE_UNAVAILABLE, "Authentication service unavailable", ex);
    }
    if (!Objects.equals(expected, providedToken)) {
      log.info("Auth token mismatch detected; refreshing from source");
      authTokenProvider.refresh();
      String refreshed;
      try {
        refreshed = authTokenProvider.requiredToken();
      } catch (IllegalStateException ex) {
        log.error("Auth token refresh failed", ex);
        throw new ResponseStatusException(
            HttpStatus.SERVICE_UNAVAILABLE, "Authentication service unavailable", ex);
      }
      if (!Objects.equals(refreshed, providedToken)) {
        log.warn("Unauthorized request denied: expected token {}, received {}", REDACTED, REDACTED);
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized");
      }
    }
  }
}
