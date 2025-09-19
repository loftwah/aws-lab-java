package com.deanlofts.awslabjava.application.service;

import java.util.List;
import java.util.UUID;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.deanlofts.awslabjava.application.domain.WidgetRequest;
import com.deanlofts.awslabjava.application.dto.WidgetDto;
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
  public List<WidgetDto> findAll() {
    return widgetRepository.findAll().stream().map(this::toDto).toList();
  }

  @Transactional(readOnly = true)
  public WidgetDto findById(UUID id) {
    return widgetRepository
        .findById(id)
        .map(this::toDto)
        .orElseThrow(
            () ->
                new ResponseStatusException(
                    HttpStatus.NOT_FOUND, "Widget %s not found".formatted(id)));
  }

  public WidgetDto create(WidgetRequest request) {
    WidgetEntity entity =
        WidgetEntity.builder().name(request.name()).description(request.description()).build();
    WidgetDto saved = toDto(widgetRepository.save(entity));
    s3MetadataService.writeWidgetMetadata(saved);
    return saved;
  }

  public WidgetDto update(UUID id, WidgetRequest request) {
    WidgetEntity entity =
        widgetRepository
            .findById(id)
            .orElseThrow(
                () ->
                    new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Widget %s not found".formatted(id)));
    entity.setName(request.name());
    entity.setDescription(request.description());
    WidgetDto updated = toDto(widgetRepository.save(entity));
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

  private WidgetDto toDto(WidgetEntity entity) {
    return new WidgetDto(
        entity.getId(),
        entity.getName(),
        entity.getDescription(),
        entity.getCreatedAt(),
        entity.getUpdatedAt());
  }
}
