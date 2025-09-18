package com.deanlofts.awslabjava.application.service;

import com.deanlofts.awslabjava.application.config.AppProperties;
import java.time.Instant;
import java.util.Map;
import org.springframework.stereotype.Service;

@Service
public class HealthStatusService {

    private final AppProperties appProperties;

    public HealthStatusService(AppProperties appProperties) {
        this.appProperties = appProperties;
    }

    public Map<String, Object> currentHealth() {
        // TODO: Replace placeholder dependency checks with real integrations when wired.
        return Map.of(
                "status", "UP",
                "timestamp", Instant.now().toString(),
                "deploymentTarget", appProperties.getDeploymentTarget(),
                "dependencies",
                        Map.of(
                                "rds", Map.of("status", "UNKNOWN", "details", "Pending integration"),
                                "secretsManager", Map.of("status", "UNKNOWN", "details", "Pending integration"),
                                "s3", Map.of("status", appProperties.getFeature().isS3Metadata() ? "UNKNOWN" : "DISABLED")),
                "buildInfo", Map.of("service", appProperties.getName()));
    }
}
