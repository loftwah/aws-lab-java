package com.deanlofts.awslabjava.application.service;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.deanlofts.awslabjava.application.domain.Widget;
import com.deanlofts.awslabjava.application.domain.WidgetRequest;
import com.deanlofts.awslabjava.application.entity.WidgetEntity;
import com.deanlofts.awslabjava.application.repository.WidgetRepository;

@Service
@Transactional
public class WidgetService {

  private final WidgetRepository widgetRepository;
  private final S3MetadataService s3MetadataService;

  public WidgetService(WidgetRepository widgetRepository, S3MetadataService s3MetadataService) {
    this.widgetRepository = widgetRepository;
    this.s3MetadataService = s3MetadataService;
  }

  @Transactional(readOnly = true)
  public List<Widget> findAll() {
    return widgetRepository.findAll().stream().map(this::toDomain).toList();
  }

  @Transactional(readOnly = true)
  public Widget findById(UUID id) {
    return widgetRepository
        .findById(id)
        .map(this::toDomain)
        .orElseThrow(
            () ->
                new ResponseStatusException(
                    HttpStatus.NOT_FOUND, "Widget %s not found".formatted(id)));
  }

  public Widget create(WidgetRequest request) {
    WidgetEntity entity = new WidgetEntity();
    entity.setId(UUID.randomUUID());
    entity.setName(request.name());
    entity.setDescription(request.description());
    Instant now = Instant.now();
    entity.setCreatedAt(now);
    entity.setUpdatedAt(now);
    Widget saved = toDomain(widgetRepository.save(entity));
    s3MetadataService.writeWidgetMetadata(saved);
    return saved;
  }

  public Widget update(UUID id, WidgetRequest request) {
    WidgetEntity entity =
        widgetRepository
            .findById(id)
            .orElseThrow(
                () ->
                    new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Widget %s not found".formatted(id)));
    entity.setName(request.name());
    entity.setDescription(request.description());
    entity.setUpdatedAt(Instant.now());
    Widget updated = toDomain(widgetRepository.save(entity));
    s3MetadataService.writeWidgetMetadata(updated);
    return updated;
  }

  public void delete(UUID id) {
    try {
      widgetRepository.deleteById(id);
      s3MetadataService.deleteWidgetMetadata(id.toString());
    } catch (EmptyResultDataAccessException ex) {
      throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Widget %s not found".formatted(id));
    }
  }

  private Widget toDomain(WidgetEntity entity) {
    return new Widget(
        entity.getId(),
        entity.getName(),
        entity.getDescription(),
        entity.getCreatedAt(),
        entity.getUpdatedAt());
  }
}
