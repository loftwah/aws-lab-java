package com.deanlofts.awslabjava.application.health;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.boot.actuate.health.Status;

import com.deanlofts.awslabjava.application.config.AppProperties;
import com.deanlofts.awslabjava.application.config.AwsProperties;

import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

class S3HealthIndicatorTest {

  private final S3Client s3Client = mock(S3Client.class);

  @Test
  void reportsUpWhenFeatureDisabled() {
    AppProperties.Feature feature = new AppProperties.Feature(false);
    AppProperties appProperties = new AppProperties("demo", "tester", "test", "token", feature);
    AwsProperties awsProperties = new AwsProperties(null, null, null, null);

    S3HealthIndicator indicator =
        new S3HealthIndicator(appProperties, awsProperties, Optional.empty());

    assertThat(indicator.health().getStatus()).isEqualTo(Status.UP);
    verifyNoInteractions(s3Client);
  }

  @Test
  void reportsDownWhenBucketMissing() {
    AppProperties.Feature feature = new AppProperties.Feature(true);
    AppProperties appProperties = new AppProperties("demo", "tester", "test", "token", feature);
    AwsProperties.S3 s3 = new AwsProperties.S3(null, "widget-metadata/");
    AwsProperties awsProperties = new AwsProperties(null, null, null, s3);

    S3HealthIndicator indicator =
        new S3HealthIndicator(appProperties, awsProperties, Optional.of(s3Client));

    assertThat(indicator.health().getStatus()).isEqualTo(Status.DOWN);
    assertThat(indicator.health().getDetails()).containsEntry("error", "bucket-not-configured");
  }

  @Test
  void reportsDownWhenS3Throws() {
    AppProperties.Feature feature = new AppProperties.Feature(true);
    AppProperties appProperties = new AppProperties("demo", "tester", "test", "token", feature);
    AwsProperties.S3 s3 = new AwsProperties.S3("demo-bucket", "widget-metadata/");
    AwsProperties awsProperties = new AwsProperties(null, null, null, s3);

    when(s3Client.headBucket(any(HeadBucketRequest.class)))
        .thenThrow(S3Exception.builder().statusCode(500).build());

    S3HealthIndicator indicator =
        new S3HealthIndicator(appProperties, awsProperties, Optional.of(s3Client));

    assertThat(indicator.health().getStatus()).isEqualTo(Status.DOWN);
  }
}
