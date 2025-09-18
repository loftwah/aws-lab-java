package com.deanlofts.awslabjava.application.health;

import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

import com.deanlofts.awslabjava.application.service.AuthTokenProvider;

@Component
public class AuthTokenHealthIndicator implements HealthIndicator {

  private static final Logger log = LoggerFactory.getLogger(AuthTokenHealthIndicator.class);

  private final AuthTokenProvider authTokenProvider;

  public AuthTokenHealthIndicator(AuthTokenProvider authTokenProvider) {
    this.authTokenProvider = authTokenProvider;
  }

  @Override
  public Health health() {
    Optional<AuthTokenProvider.Metadata> metadata = authTokenProvider.metadata();
    if (metadata.isPresent()) {
      AuthTokenProvider.Metadata snapshot = metadata.get();
      return Health.up()
          .withDetail("source", snapshot.source().name())
          .withDetail("fetchedAt", snapshot.fetchedAt().toString())
          .build();
    }

    log.warn("Auth token metadata unavailable; reporting health DOWN");
    return Health.down().withDetail("error", "UNAVAILABLE").build();
  }
}
