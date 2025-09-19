package com.deanlofts.awslabjava.application.dto;

import java.time.Instant;
import java.util.UUID;

public record WidgetDto(
    UUID id, String name, String description, Instant createdAt, Instant updatedAt) {}
