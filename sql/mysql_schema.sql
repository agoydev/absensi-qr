-- MySQL schema for Absensi QR
-- Create database first or run in the desired schema

CREATE TABLE IF NOT EXISTS `users` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `username` VARCHAR(100) NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `role` VARCHAR(20) NOT NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `chk_users_role` CHECK (`role` IN ('admin', 'teacher'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `classes` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  `grade_level` VARCHAR(20) NOT NULL,
  `major` VARCHAR(100) NOT NULL,
  `school_year` VARCHAR(20) NOT NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_class_year` (`name`, `school_year`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `students` ( -- tabel siswa
  `id` INT NOT NULL AUTO_INCREMENT,
  `class_id` INT NULL,
  `name` VARCHAR(255) NOT NULL,
  `nis` VARCHAR(100) NOT NULL UNIQUE,
  `class_name` VARCHAR(100) NOT NULL,
  `qr_code` VARCHAR(255) NOT NULL UNIQUE,
  `parent_name` VARCHAR(255) NULL,
  `parent_phone` VARCHAR(30) NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
  ,CONSTRAINT `fk_students_class` FOREIGN KEY (`class_id`) REFERENCES `classes`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `subjects` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(50) NOT NULL UNIQUE,
  `name` VARCHAR(255) NOT NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `schedules` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `class_id` INT NOT NULL,
  `subject_id` INT NOT NULL,
  `teacher_id` INT NOT NULL,
  `day_of_week` TINYINT NOT NULL,
  `start_time` TIME NOT NULL,
  `end_time` TIME NOT NULL,
  `late_after_minutes` SMALLINT NOT NULL DEFAULT 15,
  `school_year` VARCHAR(20) NOT NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`id`),
  CONSTRAINT `chk_schedules_day` CHECK (`day_of_week` BETWEEN 1 AND 7),
  CONSTRAINT `chk_schedules_time` CHECK (`end_time` > `start_time`),
  CONSTRAINT `fk_schedules_class` FOREIGN KEY (`class_id`) REFERENCES `classes`(`id`),
  CONSTRAINT `fk_schedules_subject` FOREIGN KEY (`subject_id`) REFERENCES `subjects`(`id`),
  CONSTRAINT `fk_schedules_teacher` FOREIGN KEY (`teacher_id`) REFERENCES `users`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sessions` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `schedule_id` INT NOT NULL,
  `session_date` DATE NOT NULL,
  `meeting_number` INT NOT NULL,
  `start_at` DATETIME NOT NULL,
  `end_at` DATETIME NOT NULL,
  `attendance_deadline` DATETIME NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'scheduled',
  `opened_by` INT NULL,
  `opened_at` DATETIME NULL,
  `closed_by` INT NULL,
  `closed_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_schedule_date` (`schedule_id`, `session_date`),
  CONSTRAINT `chk_sessions_status` CHECK (`status` IN ('scheduled', 'ongoing', 'completed', 'cancelled')),
  CONSTRAINT `fk_sessions_schedule` FOREIGN KEY (`schedule_id`) REFERENCES `schedules`(`id`),
  CONSTRAINT `fk_sessions_opened_by` FOREIGN KEY (`opened_by`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_sessions_closed_by` FOREIGN KEY (`closed_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `attendance` ( -- tabel kehadiran
  `id` INT NOT NULL AUTO_INCREMENT,
  `session_id` INT NULL,
  `student_id` INT NOT NULL,
  `student_name` VARCHAR(255) NOT NULL,
  `date` DATE NOT NULL,
  `time` TIME NOT NULL,
  `status` VARCHAR(50) NOT NULL,
  `notes` VARCHAR(500) NULL,
  `recorded_by` INT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_attendance_student` (`student_id`),
  INDEX `idx_attendance_session` (`session_id`),
  UNIQUE KEY `uniq_student_session` (`session_id`, `student_id`),
  CONSTRAINT `chk_attendance_status` CHECK (`status` IN ('Hadir', 'Terlambat', 'Sakit', 'Izin', 'Dispensasi', 'Tidak Hadir')),
  CONSTRAINT `fk_attendance_session` FOREIGN KEY (`session_id`) REFERENCES `sessions`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_attendance_student` FOREIGN KEY (`student_id`) REFERENCES `students`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_attendance_recorded_by` FOREIGN KEY (`recorded_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `whatsapp_notifications` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `attendance_id` INT NOT NULL,
  `student_id` INT NOT NULL,
  `parent_phone` VARCHAR(30) NOT NULL,
  `message` VARCHAR(1000) NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
  `provider_message_id` VARCHAR(255) NULL,
  `error_message` VARCHAR(500) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `sent_at` DATETIME NULL,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_notification_attendance` (`attendance_id`),
  INDEX `idx_notification_status` (`status`),
  CONSTRAINT `fk_notification_attendance`
    FOREIGN KEY (`attendance_id`) REFERENCES `attendance`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_notification_student`
    FOREIGN KEY (`student_id`) REFERENCES `students`(`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_notification_status`
    CHECK (`status` IN ('pending', 'sent', 'failed'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
