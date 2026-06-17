-- reset.sql
-- Drops all tables and recreates the student table with seed data.
-- Run this from the mysql CLI:  source schema/reset.sql;
-- Or run each file individually in order.

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS grade;
DROP TABLE IF EXISTS payment;
DROP TABLE IF EXISTS student_account;
DROP TABLE IF EXISTS enrollment;
DROP TABLE IF EXISTS course;
DROP TABLE IF EXISTS student;

SET FOREIGN_KEY_CHECKS = 1;

-- Recreate tables in dependency order
-- (Only student exists so far — more tables will be added as lessons progress)

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
