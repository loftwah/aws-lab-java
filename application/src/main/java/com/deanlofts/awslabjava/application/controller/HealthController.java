package com.deanlofts.awslabjava.application.controller;

import com.deanlofts.awslabjava.application.service.HealthStatusService;
import java.util.Map;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {

    private final HealthStatusService healthStatusService;

    public HealthController(HealthStatusService healthStatusService) {
        this.healthStatusService = healthStatusService;
    }

    @GetMapping(path = "/healthz", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> health() {
        return healthStatusService.currentHealth();
    }
}
