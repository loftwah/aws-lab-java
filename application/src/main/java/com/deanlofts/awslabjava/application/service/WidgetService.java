package com.deanlofts.awslabjava.application.service;

import com.deanlofts.awslabjava.application.domain.Widget;
import com.deanlofts.awslabjava.application.domain.WidgetRequest;
import com.deanlofts.awslabjava.application.entity.WidgetEntity;
import com.deanlofts.awslabjava.application.repository.WidgetRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
@Transactional
public class WidgetService {

    private final WidgetRepository widgetRepository;

    public WidgetService(WidgetRepository widgetRepository) {
        this.widgetRepository = widgetRepository;
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
                .orElseThrow(() ->
                        new ResponseStatusException(HttpStatus.NOT_FOUND, "Widget %s not found".formatted(id)));
    }

    public Widget create(WidgetRequest request) {
        WidgetEntity entity = new WidgetEntity();
        entity.setId(UUID.randomUUID());
        entity.setName(request.name());
        entity.setDescription(request.description());
        Instant now = Instant.now();
        entity.setCreatedAt(now);
        entity.setUpdatedAt(now);
        return toDomain(widgetRepository.save(entity));
    }

    public Widget update(UUID id, WidgetRequest request) {
        WidgetEntity entity = widgetRepository
                .findById(id)
                .orElseThrow(() ->
                        new ResponseStatusException(HttpStatus.NOT_FOUND, "Widget %s not found".formatted(id)));
        entity.setName(request.name());
        entity.setDescription(request.description());
        entity.setUpdatedAt(Instant.now());
        return toDomain(widgetRepository.save(entity));
    }

    public void delete(UUID id) {
        try {
            widgetRepository.deleteById(id);
        } catch (EmptyResultDataAccessException ex) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Widget %s not found".formatted(id));
        }
    }

    private Widget toDomain(WidgetEntity entity) {
        return new Widget(entity.getId(), entity.getName(), entity.getDescription(), entity.getCreatedAt(), entity.getUpdatedAt());
    }
}
