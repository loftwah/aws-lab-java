package com.deanlofts.awslabjava.application.domain;

import jakarta.validation.constraints.NotBlank;

public record WidgetRequest(@NotBlank String name, @NotBlank String description) {
}
