package com.deanlofts.awslabjava.application.service;

import java.time.Instant;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

import com.deanlofts.awslabjava.application.config.AppProperties;
import com.deanlofts.awslabjava.application.config.AwsProperties;

import software.amazon.awssdk.awscore.exception.AwsServiceException;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;
import software.amazon.awssdk.services.ssm.SsmClient;
import software.amazon.awssdk.services.ssm.model.GetParameterRequest;

@Component
public class AuthTokenProvider {

  private static final Logger log = LoggerFactory.getLogger(AuthTokenProvider.class);

  private final AppProperties appProperties;
  private final AwsProperties awsProperties;
  private final Optional<SecretsManagerClient> secretsManagerClient;
  private final Optional<SsmClient> ssmClient;
  private final AtomicReference<TokenSnapshot> cache = new AtomicReference<>();

  public AuthTokenProvider(
      AppProperties appProperties,
      AwsProperties awsProperties,
      Optional<SecretsManagerClient> secretsManagerClient,
      Optional<SsmClient> ssmClient) {
    this.appProperties = appProperties;
    this.awsProperties = awsProperties;
    this.secretsManagerClient = secretsManagerClient;
    this.ssmClient = ssmClient;
  }

  public String requiredToken() {
    return resolveToken().token();
  }

  public void refresh() {
    cache.set(null);
  }

  private TokenSnapshot resolveToken() {
    TokenSnapshot snapshot = cache.get();
    if (snapshot != null) {
      return snapshot;
    }
    synchronized (cache) {
      snapshot = cache.get();
      if (snapshot == null) {
        snapshot = loadToken();
        cache.set(snapshot);
        log.info("Demo auth token loaded from {} at {}", snapshot.source, snapshot.fetchedAt);
      }
      return snapshot;
    }
  }

  public Optional<Metadata> metadata() {
    try {
      TokenSnapshot snapshot = resolveToken();
      return Optional.of(new Metadata(snapshot.source, snapshot.fetchedAt));
    } catch (IllegalStateException ex) {
      log.warn("Auth token metadata lookup failed", ex);
      return Optional.empty();
    }
  }

  private TokenSnapshot loadToken() {
    String secretId = awsProperties.getSecrets().getAuthTokenSecretId();
    if (StringUtils.hasText(secretId)) {
      SecretsManagerClient client =
          secretsManagerClient.orElseThrow(
              () ->
                  new IllegalStateException(
                      "Secrets Manager client missing while secret id configured"));
      try {
        String secretValue =
            client
                .getSecretValue(GetSecretValueRequest.builder().secretId(secretId).build())
                .secretString();
        if (!StringUtils.hasText(secretValue)) {
          throw new IllegalStateException("Secrets Manager secret is empty");
        }
        return new TokenSnapshot(secretValue, TokenSource.SECRETS_MANAGER, Instant.now());
      } catch (AwsServiceException ex) {
        throw new IllegalStateException("Failed to fetch secret from Secrets Manager", ex);
      }
    }

    String parameterName = awsProperties.getParameterStore().getAuthTokenParameterName();
    if (StringUtils.hasText(parameterName)) {
      SsmClient client =
          ssmClient.orElseThrow(
              () ->
                  new IllegalStateException("SSM client missing while parameter name configured"));
      try {
        String parameterValue =
            client
                .getParameter(
                    GetParameterRequest.builder().name(parameterName).withDecryption(true).build())
                .parameter()
                .value();
        if (!StringUtils.hasText(parameterValue)) {
          throw new IllegalStateException("SSM parameter is empty");
        }
        return new TokenSnapshot(parameterValue, TokenSource.PARAMETER_STORE, Instant.now());
      } catch (AwsServiceException ex) {
        throw new IllegalStateException("Failed to fetch parameter from SSM", ex);
      }
    }

    String configuredToken = appProperties.getAuthToken();
    if (StringUtils.hasText(configuredToken)) {
      return new TokenSnapshot(configuredToken, TokenSource.APPLICATION_PROPERTIES, Instant.now());
    }

    throw new IllegalStateException(
        "No authentication token configured via Secrets Manager, SSM, or properties");
  }

  public record Metadata(TokenSource source, Instant fetchedAt) {}

  private record TokenSnapshot(String token, TokenSource source, Instant fetchedAt) {}

  public enum TokenSource {
    SECRETS_MANAGER,
    PARAMETER_STORE,
    APPLICATION_PROPERTIES
  }
}
