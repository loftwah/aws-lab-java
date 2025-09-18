package com.deanlofts.awslabjava.application;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan("com.deanlofts.awslabjava.application.config")
public class AwsLabJavaDemoApplication {

  public static void main(String[] args) {
    SpringApplication.run(AwsLabJavaDemoApplication.class, args);
  }
}
