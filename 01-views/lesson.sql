-- ============================================================
-- SQL VIEWS LESSON
-- Using the `student` table as our example
-- ============================================================


-- ============================================================
-- 1. WHAT IS A VIEW?
-- A view is a saved SELECT query stored as a virtual table.
-- It has no data of its own — it reads from the underlying
-- table every time you query it. Think of it as a "lens"
-- or "shortcut" over your data.
-- ============================================================


-- ============================================================
-- 2. CREATE VIEW
-- Syntax: CREATE VIEW <view_name> AS <SELECT query>;
--
-- This view hides sensitive fields and exposes only
-- the contact information of each student.
-- ============================================================

CREATE VIEW student_contacts AS
SELECT student_id, name, email
FROM student;


-- ============================================================
-- 3. QUERYING A VIEW
-- You query a view exactly like a regular table.
-- ============================================================

SELECT * FROM student_contacts;


-- ============================================================
-- 4. VIEW WITH A WHERE CLAUSE
-- You can filter rows inside a view.
-- This view shows only female students.
-- ============================================================

CREATE VIEW female_students AS
SELECT student_id, name, date_of_birth
FROM student
WHERE gender = 'Female';

SELECT * FROM female_students;


-- ============================================================
-- 5. VIEW WITH A COMPUTED COLUMN
-- Views can include calculated values.
-- This view calculates each student's current age.
-- ============================================================

CREATE VIEW student_ages AS
SELECT student_id, name,
       TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS age
FROM student;

SELECT * FROM student_ages;


-- ============================================================
-- 6. CREATE OR REPLACE VIEW
-- Updates an existing view without dropping it first.
-- Here we add the `gender` column to student_contacts.
-- ============================================================

CREATE OR REPLACE VIEW student_contacts AS
SELECT student_id, name, email, gender
FROM student;

SELECT * FROM student_contacts;


-- ============================================================
-- 7. DROP VIEW
-- Removes a view. IF EXISTS prevents an error if it's
-- already been deleted.
-- Note: this does NOT delete the underlying table data.
-- ============================================================

DROP VIEW IF EXISTS female_students;
DROP VIEW IF EXISTS student_ages;
DROP VIEW IF EXISTS student_contacts;


-- ============================================================
-- KEY LIMITATIONS IN MYSQL
-- - Views cannot use variables or dynamic SQL
-- - Views with GROUP BY, DISTINCT, or aggregate functions
--   (SUM, COUNT, etc.) are NOT updatable — you can SELECT
--   from them but not INSERT/UPDATE/DELETE through them
-- ============================================================
