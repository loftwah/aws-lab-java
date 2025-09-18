package com.deanlofts.awslabjava.application.service;

import java.time.Instant;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.util.Assert;
import org.springframework.util.StringUtils;

import com.deanlofts.awslabjava.application.config.AppProperties;
import com.deanlofts.awslabjava.application.config.AwsProperties;
import com.deanlofts.awslabjava.application.domain.Widget;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

@Service
public class S3MetadataService {

  private static final Logger log = LoggerFactory.getLogger(S3MetadataService.class);

  private final AppProperties appProperties;
  private final AwsProperties awsProperties;
  private final Optional<S3Client> s3Client;
  private final ObjectMapper objectMapper;

  public S3MetadataService(
      AppProperties appProperties,
      AwsProperties awsProperties,
      Optional<S3Client> s3Client,
      ObjectMapper objectMapper) {
    this.appProperties = appProperties;
    this.awsProperties = awsProperties;
    this.s3Client = s3Client;
    this.objectMapper = objectMapper;
  }

  public boolean isEnabled() {
    return appProperties.getFeature().isS3Metadata();
  }

  public void writeWidgetMetadata(Widget widget) {
    if (!isEnabled()) {
      return;
    }
    S3Context context = resolveContext();
    try {
      String objectKey = context.objectKey(widget.id().toString());
      String payload =
          objectMapper.writeValueAsString(
              new WidgetMetadata(widget, Instant.now(), context.deploymentTarget()));
      PutObjectRequest request =
          PutObjectRequest.builder()
              .bucket(context.bucketName())
              .key(objectKey)
              .contentType("application/json")
              .build();
      context.client().putObject(request, RequestBody.fromString(payload));
      log.info("Widget metadata stored in S3 bucket={} key={}", context.bucketName(), objectKey);
    } catch (JsonProcessingException ex) {
      throw new IllegalStateException("Failed to serialise widget metadata", ex);
    }
  }

  public void deleteWidgetMetadata(String widgetId) {
    if (!isEnabled()) {
      return;
    }
    S3Context context = resolveContext();
    String objectKey = context.objectKey(widgetId);
    DeleteObjectRequest request =
        DeleteObjectRequest.builder().bucket(context.bucketName()).key(objectKey).build();
    context.client().deleteObject(request);
    log.info("Widget metadata deleted from S3 bucket={} key={}", context.bucketName(), objectKey);
  }

  private S3Context resolveContext() {
    Assert.isTrue(
        appProperties.getFeature().isS3Metadata(), "S3 metadata feature flag must be enabled");
    String bucketName = awsProperties.getS3().getBucketName();
    if (!StringUtils.hasText(bucketName)) {
      throw new IllegalStateException(
          "S3 metadata enabled but aws.s3.bucket-name is not configured");
    }
    S3Client client =
        s3Client.orElseThrow(
            () -> new IllegalStateException("S3 metadata enabled but S3 client is not available"));
    String prefix = awsProperties.getS3().getPrefix();
    String deploymentTarget = appProperties.getDeploymentTarget();
    return new S3Context(client, bucketName, prefix, deploymentTarget);
  }

  private record S3Context(
      S3Client client, String bucketName, String prefix, String deploymentTarget) {
    String objectKey(String widgetId) {
      String normalisedPrefix = StringUtils.hasText(prefix) ? prefix : "";
      if (!normalisedPrefix.endsWith("/")) {
        normalisedPrefix = normalisedPrefix + "/";
      }
      return normalisedPrefix + widgetId + ".json";
    }
  }

  private record WidgetMetadata(Widget widget, Instant capturedAt, String deploymentTarget) {}
}
