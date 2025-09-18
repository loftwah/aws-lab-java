package com.deanlofts.awslabjava.application.config;

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

  public AppProperties(
      String name, String owner, String deploymentTarget, String authToken, Feature feature) {
    this.name = name;
    this.owner = owner;
    this.deploymentTarget = deploymentTarget;
    this.authToken = authToken;
    this.feature = feature != null ? feature : new Feature(false);
  }

  @Getter
  public static class Feature {
    private final boolean s3Metadata;

    public Feature(@DefaultValue("false") boolean s3Metadata) {
      this.s3Metadata = s3Metadata;
    }
  }
}
