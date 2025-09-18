package com.deanlofts.awslabjava.application.config;

import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3ClientBuilder;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClientBuilder;
import software.amazon.awssdk.services.ssm.SsmClient;
import software.amazon.awssdk.services.ssm.SsmClientBuilder;

@Configuration
@EnableConfigurationProperties(AwsProperties.class)
public class AwsClientConfiguration {

    @Bean
    @ConditionalOnExpression("T(org.springframework.util.StringUtils).hasText('${aws.secrets.auth-token-secret-id:}')")
    SecretsManagerClient secretsManagerClient(AwsProperties properties) {
        SecretsManagerClientBuilder builder = SecretsManagerClient.builder();
        Region region = resolveRegion(properties);
        if (region != null) {
            builder = builder.region(region);
        }
        return builder.build();
    }

    @Bean
    @ConditionalOnExpression("T(org.springframework.util.StringUtils).hasText('${aws.parameter-store.auth-token-parameter-name:}')")
    SsmClient ssmClient(AwsProperties properties) {
        SsmClientBuilder builder = SsmClient.builder();
        Region region = resolveRegion(properties);
        if (region != null) {
            builder = builder.region(region);
        }
        return builder.build();
    }

    @Bean
    @ConditionalOnExpression("T(org.springframework.util.StringUtils).hasText('${aws.s3.bucket-name:}')")
    S3Client s3Client(AwsProperties properties) {
        S3ClientBuilder builder = S3Client.builder();
        Region region = resolveRegion(properties);
        if (region != null) {
            builder = builder.region(region);
        }
        return builder.build();
    }

    private Region resolveRegion(AwsProperties properties) {
        String region = properties.getRegion();
        return StringUtils.hasText(region) ? Region.of(region) : null;
    }
}
