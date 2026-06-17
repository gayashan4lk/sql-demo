-- reset.sql
-- Drops ALL tables and recreates the full university schema with seed data.
-- Run from the mysql CLI:  source schema/reset.sql;
-- Or run each numbered file individually in order: 01, 02, 03, 04, 05.

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS grade;
DROP TABLE IF EXISTS payment;
DROP TABLE IF EXISTS student_account;
DROP TABLE IF EXISTS enrollment;
DROP TABLE IF EXISTS course;
DROP TABLE IF EXISTS student;

SET FOREIGN_KEY_CHECKS = 1;


-- ========================================
-- 01: student
-- ========================================

CREATE TABLE student (
    student_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    date_of_birth DATE NOT NULL,
    gender ENUM('Male', 'Female', 'Other') NOT NULL
);

INSERT INTO student (name, email, date_of_birth, gender) VALUES
    ('Alice Johnson',   'alice.johnson@email.com',   '2001-03-15', 'Female'),
    ('Bob Smith',       'bob.smith@email.com',        '2000-07-22', 'Male'),
    ('Clara Davis',     'clara.davis@email.com',      '2002-11-08', 'Female'),
    ('Daniel Lee',      'daniel.lee@email.com',       '1999-05-30', 'Male'),
    ('Eva Martinez',    'eva.martinez@email.com',     '2001-09-14', 'Female'),
    ('Frank Wilson',    'frank.wilson@email.com',     '2000-01-25', 'Male'),
    ('Grace Taylor',    'grace.taylor@email.com',     '2003-06-03', 'Female'),
    ('Henry Brown',     'henry.brown@email.com',      '1998-12-17', 'Male'),
    ('Isla Anderson',   'isla.anderson@email.com',    '2002-04-29', 'Female'),
    ('James Thomas',    'james.thomas@email.com',     '2001-08-11', 'Male'),
    ('Harry Potter',    'harry.potter@email.com',     '1990-02-22', 'Male');


-- ========================================
-- 02: course
-- ========================================

CREATE TABLE course (
    course_id INT AUTO_INCREMENT PRIMARY KEY,
    course_code VARCHAR(10) NOT NULL UNIQUE,
    course_name VARCHAR(150) NOT NULL,
    credits INT NOT NULL DEFAULT 3,
    department VARCHAR(100) NOT NULL,
    max_enrollment INT NOT NULL DEFAULT 30
);

INSERT INTO course (course_code, course_name, credits, department, max_enrollment) VALUES
    ('CS101',   'Introduction to Computer Science', 3, 'Computer Science', 30),
    ('CS201',   'Data Structures and Algorithms',   3, 'Computer Science', 25),
    ('CS301',   'Database Systems',                 3, 'Computer Science', 25),
    ('MATH101', 'Calculus I',                       4, 'Mathematics',      35),
    ('MATH201', 'Linear Algebra',                   3, 'Mathematics',      30),
    ('ENG101',  'English Composition',              3, 'English',          40),
    ('ENG201',  'Creative Writing',                 3, 'English',          20),
    ('PHY101',  'Physics I',                        4, 'Physics',          30),
    ('PHY201',  'Quantum Mechanics',                3, 'Physics',          20);


-- ========================================
-- 03: enrollment
-- ========================================

CREATE TABLE enrollment (
    enrollment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    enrolled_date DATE NOT NULL DEFAULT (CURDATE()),
    status ENUM('Active', 'Dropped', 'Completed') NOT NULL DEFAULT 'Active',
    FOREIGN KEY (student_id) REFERENCES student(student_id),
    FOREIGN KEY (course_id) REFERENCES course(course_id),
    UNIQUE (student_id, course_id)
);

INSERT INTO enrollment (student_id, course_id, enrolled_date, status) VALUES
    (1, 1, '2025-09-01', 'Completed'),
    (1, 4, '2025-09-01', 'Completed'),
    (1, 6, '2025-09-01', 'Completed'),
    (2, 1, '2025-09-01', 'Completed'),
    (2, 2, '2025-09-01', 'Completed'),
    (3, 1, '2025-09-01', 'Active'),
    (3, 6, '2025-09-01', 'Active'),
    (4, 4, '2025-09-01', 'Completed'),
    (4, 8, '2025-09-01', 'Completed'),
    (5, 1, '2025-09-01', 'Active'),
    (5, 3, '2025-09-01', 'Active'),
    (5, 7, '2025-09-01', 'Active'),
    (6, 2, '2025-09-01', 'Completed'),
    (6, 5, '2025-09-01', 'Completed'),
    (7, 1, '2025-09-01', 'Active'),
    (7, 6, '2025-09-01', 'Active'),
    (8, 3, '2025-09-01', 'Completed'),
    (8, 8, '2025-09-01', 'Dropped'),
    (9, 4, '2025-09-01', 'Active'),
    (9, 7, '2025-09-01', 'Active'),
    (10, 1, '2025-09-01', 'Active'),
    (10, 5, '2025-09-01', 'Active'),
    (11, 9, '2025-09-01', 'Active'),
    (11, 3, '2025-09-01', 'Active');


-- ========================================
-- 04: grade + audit_log
-- ========================================

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


-- ========================================
-- 05: payment + student_account
-- ========================================

CREATE TABLE student_account (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL UNIQUE,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (student_id) REFERENCES student(student_id)
);

CREATE TABLE payment (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_date DATE NOT NULL DEFAULT (CURDATE()),
    payment_type ENUM('Tuition', 'Fee', 'Refund') NOT NULL,
    description VARCHAR(255),
    FOREIGN KEY (student_id) REFERENCES student(student_id)
);

INSERT INTO student_account (student_id, balance) VALUES
    (1,  1500.00),
    (2,  2000.00),
    (3,  800.00),
    (4,  1200.00),
    (5,  500.00),
    (6,  3000.00),
    (7,  1000.00),
    (8,  1750.00),
    (9,  600.00),
    (10, 2500.00),
    (11, 900.00);

INSERT INTO payment (student_id, amount, payment_date, payment_type, description) VALUES
    (1,  5000.00, '2025-08-15', 'Tuition', 'Fall 2025 tuition'),
    (1,   150.00, '2025-08-15', 'Fee',     'Student activity fee'),
    (2,  5000.00, '2025-08-20', 'Tuition', 'Fall 2025 tuition'),
    (3,  5000.00, '2025-08-18', 'Tuition', 'Fall 2025 tuition'),
    (4,  5000.00, '2025-08-22', 'Tuition', 'Fall 2025 tuition'),
    (5,  5000.00, '2025-08-25', 'Tuition', 'Fall 2025 tuition'),
    (6,  5000.00, '2025-08-15', 'Tuition', 'Fall 2025 tuition'),
    (8, -1500.00, '2025-10-01', 'Refund',  'Dropped PHY101 refund');
