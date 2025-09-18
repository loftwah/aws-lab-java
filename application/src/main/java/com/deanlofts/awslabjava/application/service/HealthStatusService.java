package com.deanlofts.awslabjava.application.service;

import com.deanlofts.awslabjava.application.config.AppProperties;
import com.deanlofts.awslabjava.application.config.AwsProperties;
import java.sql.Connection;
import java.sql.SQLException;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import javax.sql.DataSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

@Service
public class HealthStatusService {

    private static final Logger log = LoggerFactory.getLogger(HealthStatusService.class);

    private final AppProperties appProperties;
    private final AwsProperties awsProperties;
    private final DataSource dataSource;
    private final AuthTokenProvider authTokenProvider;
    private final Optional<S3Client> s3Client;

    public HealthStatusService(
            AppProperties appProperties,
            AwsProperties awsProperties,
            DataSource dataSource,
            AuthTokenProvider authTokenProvider,
            Optional<S3Client> s3Client) {
        this.appProperties = appProperties;
        this.awsProperties = awsProperties;
        this.dataSource = dataSource;
        this.authTokenProvider = authTokenProvider;
        this.s3Client = s3Client;
    }

    public Map<String, Object> currentHealth() {
        Map<String, Object> rds = rdsStatus();
        Map<String, Object> secretStatus = authTokenProvider.describeHealth();
        Map<String, Object> s3 = s3Status();

        return Map.of(
                "status", aggregateStatus(rds, secretStatus, s3),
                "timestamp", Instant.now().toString(),
                "deploymentTarget", appProperties.getDeploymentTarget(),
                "dependencies",
                        Map.of(
                                "rds", rds,
                                "authToken", secretStatus,
                                "s3", s3),
                "buildInfo", Map.of("service", appProperties.getName()));
    }

    private String aggregateStatus(Map<String, Object>... dependencies) {
        for (Map<String, Object> dependency : dependencies) {
            Object status = dependency.get("status");
            if ("DOWN".equals(status)) {
                return "DOWN";
            }
        }
        return "UP";
    }

    private Map<String, Object> rdsStatus() {
        try (Connection connection = dataSource.getConnection()) {
            boolean valid = connection.isValid(2);
            return Map.of(
                    "status", valid ? "UP" : "DOWN",
                    "validationQuery", "connection.isValid",
                    "details", Map.of("valid", valid));
        } catch (SQLException ex) {
            log.error("Database health check failed", ex);
            return Map.of(
                    "status", "DOWN",
                    "error", ex.getClass().getSimpleName(),
                    "message", ex.getMessage());
        }
    }

    private Map<String, Object> s3Status() {
        if (!appProperties.getFeature().isS3Metadata()) {
            return Map.of("status", "DISABLED");
        }

        String bucketName = awsProperties.getS3().getBucketName();
        if (!StringUtils.hasText(bucketName)) {
            return Map.of(
                    "status", "DOWN",
                    "message", "S3 metadata enabled but bucket name not configured");
        }

        if (s3Client.isEmpty()) {
            return Map.of(
                    "status", "DOWN",
                    "message", "S3 client not available");
        }

        try {
            s3Client.get().headBucket(HeadBucketRequest.builder().bucket(bucketName).build());
            return Map.of("status", "UP", "bucket", bucketName);
        } catch (S3Exception ex) {
            log.error("S3 health check failed", ex);
            return Map.of(
                    "status", "DOWN",
                    "error", ex.awsErrorDetails() != null ? ex.awsErrorDetails().errorCode() : ex.getClass().getSimpleName(),
                    "message", ex.getMessage(),
                    "bucket", bucketName);
        }
    }
}
