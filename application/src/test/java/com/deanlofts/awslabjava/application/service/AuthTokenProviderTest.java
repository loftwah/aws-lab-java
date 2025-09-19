package com.deanlofts.awslabjava.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.deanlofts.awslabjava.application.config.AppProperties;
import com.deanlofts.awslabjava.application.config.AwsProperties;

class AuthTokenProviderTest {

  @Test
  void fallsBackToApplicationPropertiesWhenAwsSourcesNotConfigured() {
    AppProperties appProperties =
        new AppProperties("demo", "tester", "test", "demo-token", null, null);
    AwsProperties awsProperties = new AwsProperties(null, null, null, null);

    AuthTokenProvider provider =
        new AuthTokenProvider(appProperties, awsProperties, Optional.empty(), Optional.empty());

    assertThat(provider.requiredToken()).isEqualTo("demo-token");
    assertThat(provider.metadata())
        .isPresent()
        .get()
        .extracting(AuthTokenProvider.Metadata::source)
        .isEqualTo(AuthTokenProvider.TokenSource.APPLICATION_PROPERTIES);
  }
}
