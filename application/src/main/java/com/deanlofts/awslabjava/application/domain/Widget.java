package com.deanlofts.awslabjava.application.domain;

import java.time.Instant;
import java.util.UUID;

public record Widget(
    UUID id, String name, String description, Instant createdAt, Instant updatedAt) {}
