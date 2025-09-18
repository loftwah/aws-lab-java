package com.deanlofts.awslabjava.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.deanlofts.awslabjava.application.config.AppProperties;
import com.deanlofts.awslabjava.application.config.AwsProperties;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class AuthTokenProviderTest {

    @Test
    void fallsBackToApplicationPropertiesWhenAwsSourcesNotConfigured() {
        AppProperties appProperties = new AppProperties();
        appProperties.setAuthToken("demo-token");
        AwsProperties awsProperties = new AwsProperties();

        AuthTokenProvider provider =
                new AuthTokenProvider(appProperties, awsProperties, Optional.empty(), Optional.empty());

        assertThat(provider.requiredToken()).isEqualTo("demo-token");

        Map<String, Object> health = provider.describeHealth();
        assertThat(health.get("status")).isEqualTo("UP");
        assertThat(health.get("source")).isEqualTo("APPLICATION_PROPERTIES");
    }
}
