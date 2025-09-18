package com.deanlofts.awslabjava.application.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "aws")
public class AwsProperties {

    private String region;
    private final Secrets secrets = new Secrets();
    private final ParameterStore parameterStore = new ParameterStore();
    private final S3 s3 = new S3();

    public String getRegion() {
        return region;
    }

    public void setRegion(String region) {
        this.region = region;
    }

    public Secrets getSecrets() {
        return secrets;
    }

    public ParameterStore getParameterStore() {
        return parameterStore;
    }

    public S3 getS3() {
        return s3;
    }

    public static class Secrets {
        private String authTokenSecretId;

        public String getAuthTokenSecretId() {
            return authTokenSecretId;
        }

        public void setAuthTokenSecretId(String authTokenSecretId) {
            this.authTokenSecretId = authTokenSecretId;
        }
    }

    public static class ParameterStore {
        private String authTokenParameterName;

        public String getAuthTokenParameterName() {
            return authTokenParameterName;
        }

        public void setAuthTokenParameterName(String authTokenParameterName) {
            this.authTokenParameterName = authTokenParameterName;
        }
    }

    public static class S3 {
        private String bucketName;
        private String prefix = "widget-metadata/";

        public String getBucketName() {
            return bucketName;
        }

        public void setBucketName(String bucketName) {
            this.bucketName = bucketName;
        }

        public String getPrefix() {
            return prefix;
        }

        public void setPrefix(String prefix) {
            this.prefix = prefix;
        }
    }
}
