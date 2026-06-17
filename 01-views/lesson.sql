-- ============================================================
-- SQL VIEWS LESSON
-- Run schema/01_student.sql first if you haven't already.
-- ============================================================


-- == 1. CREATE VIEW ==
-- Syntax: CREATE VIEW <view_name> AS <SELECT query>;

CREATE VIEW student_contacts AS
SELECT student_id, name, email
FROM student;


-- == 2. QUERY A VIEW ==

SELECT * FROM student_contacts;


-- == 3. VIEW WITH A WHERE CLAUSE ==

CREATE VIEW female_students AS
SELECT student_id, name, date_of_birth
FROM student
WHERE gender = 'Female';

SELECT * FROM female_students;


-- == 4. VIEW WITH A COMPUTED COLUMN ==

CREATE VIEW student_ages AS
SELECT student_id, name,
       TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS age
FROM student;

SELECT * FROM student_ages;


-- == 5. CREATE OR REPLACE VIEW ==

CREATE OR REPLACE VIEW student_contacts AS
SELECT student_id, name, email, gender
FROM student;

SELECT * FROM student_contacts;


-- == 6. DROP VIEW ==

DROP VIEW IF EXISTS female_students;
DROP VIEW IF EXISTS student_ages;
DROP VIEW IF EXISTS student_contacts;
