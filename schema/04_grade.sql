CREATE TABLE grade (
    grade_id INT AUTO_INCREMENT PRIMARY KEY,
    enrollment_id INT NOT NULL UNIQUE,
    letter_grade ENUM('A', 'B', 'C', 'D', 'F') NULL,
    numeric_grade DECIMAL(5,2) NULL,
    graded_date DATE NULL,
    FOREIGN KEY (enrollment_id) REFERENCES enrollment(enrollment_id)
);

CREATE TABLE audit_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    action VARCHAR(10) NOT NULL,
    record_id INT NOT NULL,
    old_value TEXT NULL,
    new_value TEXT NULL,
    changed_by VARCHAR(100) NOT NULL DEFAULT (CURRENT_USER()),
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Grades for completed enrollments
INSERT INTO grade (enrollment_id, letter_grade, numeric_grade, graded_date) VALUES
    (1,  'A', 92.50, '2025-12-15'),
    (2,  'B', 85.00, '2025-12-15'),
    (3,  'A', 94.00, '2025-12-15'),
    (4,  'B', 83.50, '2025-12-15'),
    (5,  'A', 91.00, '2025-12-15'),
    (8,  'C', 74.00, '2025-12-15'),
    (9,  'B', 86.50, '2025-12-15'),
    (13, 'D', 65.00, '2025-12-15'),
    (14, 'A', 95.00, '2025-12-15'),
    (17, 'B', 88.00, '2025-12-15');
