package com.deanlofts.awslabjava.application.controller;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.deanlofts.awslabjava.application.domain.WidgetRequest;
import com.deanlofts.awslabjava.application.dto.WidgetDto;
import com.deanlofts.awslabjava.application.service.AuthService;
import com.deanlofts.awslabjava.application.service.WidgetService;

@RestController
@RequestMapping(path = "/api/v1/widgets", produces = MediaType.APPLICATION_JSON_VALUE)
public class WidgetController {

  private static final String AUTH_HEADER = "X-Demo-Auth";

  private final WidgetService widgetService;
  private final AuthService authService;

  public WidgetController(WidgetService widgetService, AuthService authService) {
    this.widgetService = widgetService;
    this.authService = authService;
  }

  @GetMapping
  public List<WidgetDto> list() {
    return widgetService.findAll();
  }

  @GetMapping("/{id}")
  public WidgetDto get(@PathVariable UUID id) {
    return widgetService.findById(id);
  }

  @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
  @ResponseStatus(HttpStatus.CREATED)
  public WidgetDto create(
      @RequestHeader(AUTH_HEADER) String token, @Valid @RequestBody WidgetRequest request) {
    authService.assertAuthorized(token);
    return widgetService.create(request);
  }

  @PutMapping(path = "/{id}", consumes = MediaType.APPLICATION_JSON_VALUE)
  public WidgetDto update(
      @RequestHeader(AUTH_HEADER) String token,
      @PathVariable UUID id,
      @Valid @RequestBody WidgetRequest request) {
    authService.assertAuthorized(token);
    return widgetService.update(id, request);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void delete(@RequestHeader(AUTH_HEADER) String token, @PathVariable UUID id) {
    authService.assertAuthorized(token);
    widgetService.delete(id);
  }
}
