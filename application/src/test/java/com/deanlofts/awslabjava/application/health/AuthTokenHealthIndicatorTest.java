package com.deanlofts.awslabjava.application.health;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.boot.actuate.health.Status;

import com.deanlofts.awslabjava.application.service.AuthTokenProvider;
import com.deanlofts.awslabjava.application.service.AuthTokenProvider.Metadata;
import com.deanlofts.awslabjava.application.service.AuthTokenProvider.TokenSource;

class AuthTokenHealthIndicatorTest {

  private final AuthTokenProvider authTokenProvider = mock(AuthTokenProvider.class);
  private final AuthTokenHealthIndicator indicator =
      new AuthTokenHealthIndicator(authTokenProvider);

  @Test
  void reportsUpWhenMetadataAvailable() {
    Metadata metadata =
        new Metadata(TokenSource.APPLICATION_PROPERTIES, Instant.parse("2024-01-01T00:00:00Z"));
    when(authTokenProvider.metadata()).thenReturn(Optional.of(metadata));

    assertThat(indicator.health().getStatus()).isEqualTo(Status.UP);
  }

  @Test
  void reportsDownWhenMetadataMissing() {
    when(authTokenProvider.metadata()).thenReturn(Optional.empty());

    assertThat(indicator.health().getStatus()).isEqualTo(Status.DOWN);
    assertThat(indicator.health().getDetails()).containsEntry("error", "UNAVAILABLE");
  }
}
