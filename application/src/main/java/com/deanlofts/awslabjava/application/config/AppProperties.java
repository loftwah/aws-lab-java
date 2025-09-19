package com.deanlofts.awslabjava.application.config;

import java.util.List;

import jakarta.validation.constraints.NotBlank;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;
import org.springframework.validation.annotation.Validated;

import lombok.Getter;

@ConfigurationProperties(prefix = "app")
@Validated
@Getter
public class AppProperties {

  @NotBlank private final String name;

  @NotBlank private final String owner;

  @NotBlank private final String deploymentTarget;

  private final String authToken;

  private final Feature feature;
  private final Cors cors;

  public AppProperties(
      String name,
      String owner,
      String deploymentTarget,
      String authToken,
      Feature feature,
      Cors cors) {
    this.name = name;
    this.owner = owner;
    this.deploymentTarget = deploymentTarget;
    this.authToken = authToken;
    this.feature = feature != null ? feature : new Feature(false);
    this.cors = cors != null ? cors : new Cors(List.of());
  }

  @Getter
  public static class Feature {
    private final boolean s3Metadata;

    public Feature(@DefaultValue("false") boolean s3Metadata) {
      this.s3Metadata = s3Metadata;
    }
  }

  @Getter
  public static class Cors {
    private final List<String> allowedOrigins;

    public Cors(List<String> allowedOrigins) {
      this.allowedOrigins =
          allowedOrigins == null || allowedOrigins.isEmpty()
              ? List.of()
              : List.copyOf(allowedOrigins);
    }
  }
}
