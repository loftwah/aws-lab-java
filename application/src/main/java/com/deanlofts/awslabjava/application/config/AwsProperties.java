package com.deanlofts.awslabjava.application.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

import lombok.Getter;

@ConfigurationProperties(prefix = "aws")
@Getter
public class AwsProperties {

  private final String region;
  private final Secrets secrets;
  private final ParameterStore parameterStore;
  private final S3 s3;

  public AwsProperties(String region, Secrets secrets, ParameterStore parameterStore, S3 s3) {
    this.region = region;
    this.secrets = secrets != null ? secrets : new Secrets(null);
    this.parameterStore = parameterStore != null ? parameterStore : new ParameterStore(null);
    this.s3 = s3 != null ? s3 : new S3(null, "widget-metadata/");
  }

  @Getter
  public static class Secrets {
    private final String authTokenSecretId;

    public Secrets(String authTokenSecretId) {
      this.authTokenSecretId = authTokenSecretId;
    }
  }

  @Getter
  public static class ParameterStore {
    private final String authTokenParameterName;

    public ParameterStore(String authTokenParameterName) {
      this.authTokenParameterName = authTokenParameterName;
    }
  }

  @Getter
  public static class S3 {
    private final String bucketName;
    private final String prefix;

    public S3(String bucketName, @DefaultValue("widget-metadata/") String prefix) {
      this.bucketName = bucketName;
      this.prefix = prefix;
    }
  }
}
