package com.deanlofts.awslabjava.application.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.deanlofts.awslabjava.application.entity.WidgetEntity;

public interface WidgetRepository extends JpaRepository<WidgetEntity, UUID> {}
