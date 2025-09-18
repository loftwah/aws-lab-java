package com.deanlofts.awslabjava.application.health;

import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

import com.deanlofts.awslabjava.application.config.AppProperties;
import com.deanlofts.awslabjava.application.config.AwsProperties;

import software.amazon.awssdk.core.exception.SdkClientException;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

@Component
public class S3HealthIndicator implements HealthIndicator {

  private static final Logger log = LoggerFactory.getLogger(S3HealthIndicator.class);

  private final AppProperties appProperties;
  private final AwsProperties awsProperties;
  private final Optional<S3Client> s3Client;

  public S3HealthIndicator(
      AppProperties appProperties, AwsProperties awsProperties, Optional<S3Client> s3Client) {
    this.appProperties = appProperties;
    this.awsProperties = awsProperties;
    this.s3Client = s3Client;
  }

  @Override
  public Health health() {
    if (!appProperties.getFeature().isS3Metadata()) {
      return Health.up().withDetail("feature", "disabled").build();
    }

    String bucketName = awsProperties.getS3().getBucketName();
    if (!StringUtils.hasText(bucketName)) {
      return Health.down().withDetail("error", "bucket-not-configured").build();
    }

    if (s3Client.isEmpty()) {
      return Health.down().withDetail("error", "s3-client-missing").build();
    }

    try {
      s3Client.get().headBucket(HeadBucketRequest.builder().bucket(bucketName).build());
      return Health.up().withDetail("bucket", bucketName).build();
    } catch (S3Exception ex) {
      log.warn("S3 health check failed", ex);
      return Health.down()
          .withDetail(
              "error", ex.awsErrorDetails() != null ? ex.awsErrorDetails().errorCode() : "s3-error")
          .withDetail("statusCode", ex.statusCode())
          .build();
    } catch (SdkClientException ex) {
      log.warn("S3 health check failed", ex);
      return Health.down().withDetail("error", "sdk-client-error").build();
    }
  }
}
