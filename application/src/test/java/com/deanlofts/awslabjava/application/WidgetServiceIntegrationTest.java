package com.deanlofts.awslabjava.application;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import com.deanlofts.awslabjava.application.domain.WidgetRequest;
import com.deanlofts.awslabjava.application.dto.WidgetDto;
import com.deanlofts.awslabjava.application.service.WidgetService;

@SpringBootTest
@Testcontainers
class WidgetServiceIntegrationTest {

  @SuppressWarnings("resource")
  @Container
  static final PostgreSQLContainer<?> POSTGRES =
      new PostgreSQLContainer<>("postgres:16")
          .withDatabaseName("demo")
          .withUsername("demo")
          .withPassword("demo");

  @DynamicPropertySource
  static void postgresProperties(DynamicPropertyRegistry registry) {
    registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
    registry.add("spring.datasource.username", POSTGRES::getUsername);
    registry.add("spring.datasource.password", POSTGRES::getPassword);
    registry.add("app.auth-token", () -> "integration-token");
  }

  @Autowired private WidgetService widgetService;

  @Test
  void createAndFetchWidget() {
    WidgetDto created =
        widgetService.create(new WidgetRequest("test widget", "an integration test widget"));

    WidgetDto fetched = widgetService.findById(created.id());

    assertThat(fetched.name()).isEqualTo("test widget");
    assertThat(widgetService.findAll()).hasSize(1);

    widgetService.update(created.id(), new WidgetRequest("updated", "updated description"));

    WidgetDto updated = widgetService.findById(created.id());
    assertThat(updated.name()).isEqualTo("updated");

    widgetService.delete(created.id());
    assertThat(widgetService.findAll()).isEmpty();
  }
}
