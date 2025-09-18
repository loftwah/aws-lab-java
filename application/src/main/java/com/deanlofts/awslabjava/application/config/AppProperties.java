package com.deanlofts.awslabjava.application.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationPropertiesScan
@ConfigurationProperties(prefix = "app")
public class AppProperties {
    private String name;
    private String owner;
    private String deploymentTarget;
    private String authToken;
    private Feature feature = new Feature();

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getOwner() {
        return owner;
    }

    public void setOwner(String owner) {
        this.owner = owner;
    }

    public String getDeploymentTarget() {
        return deploymentTarget;
    }

    public void setDeploymentTarget(String deploymentTarget) {
        this.deploymentTarget = deploymentTarget;
    }

    public String getAuthToken() {
        return authToken;
    }

    public void setAuthToken(String authToken) {
        this.authToken = authToken;
    }

    public Feature getFeature() {
        return feature;
    }

    public void setFeature(Feature feature) {
        this.feature = feature;
    }

    public static class Feature {
        private boolean s3Metadata;

        public boolean isS3Metadata() {
            return s3Metadata;
        }

        public void setS3Metadata(boolean s3Metadata) {
            this.s3Metadata = s3Metadata;
        }
    }
}
