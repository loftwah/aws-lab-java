package com.deanlofts.awslabjava.application.repository;

import com.deanlofts.awslabjava.application.entity.WidgetEntity;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WidgetRepository extends JpaRepository<WidgetEntity, UUID> {
}
