package com.deanlofts.awslabjava.application.service;

import com.deanlofts.awslabjava.application.domain.Widget;
import com.deanlofts.awslabjava.application.domain.WidgetRequest;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@Service
public class WidgetService {

    private final Map<UUID, Widget> store = new ConcurrentHashMap<>();

    public List<Widget> findAll() {
        return new ArrayList<>(store.values());
    }

    public Widget findById(UUID id) {
        Widget widget = store.get(id);
        if (widget == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Widget %s not found".formatted(id));
        }
        return widget;
    }

    public Widget create(WidgetRequest request) {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        Widget widget = new Widget(id, request.name(), request.description(), now, now);
        store.put(id, widget);
        return widget;
    }

    public Widget update(UUID id, WidgetRequest request) {
        Widget existing = findById(id);
        Instant now = Instant.now();
        Widget updated = new Widget(id, request.name(), request.description(), existing.createdAt(), now);
        store.put(id, updated);
        return updated;
    }

    public void delete(UUID id) {
        Widget removed = store.remove(id);
        if (removed == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Widget %s not found".formatted(id));
        }
    }
}
