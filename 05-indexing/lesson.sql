-- =============================================================
-- 05 Indexing — Runnable Examples
-- Run schema/reset.sql first. Assumes MySQL 8.0+.
-- This script is re-runnable: it drops every index it creates at the end.
-- Pair each EXPLAIN with the prose in lesson.md.
--
-- NOTE: On these tiny seed tables the optimiser often prefers a full
-- scan even when an index exists (reading ~11 rows beats a B-tree walk).
-- Watch `possible_keys` to confirm the index *applies*; see §7 of the lesson.
-- =============================================================


-- -------------------------------------------------------------
-- 1. Reading EXPLAIN — an un-indexed column does a full scan
-- -------------------------------------------------------------
-- `name` has no index: expect type = ALL, possible_keys = NULL, rows = 11.
EXPLAIN SELECT * FROM student WHERE name = 'Grace Taylor';


-- -------------------------------------------------------------
-- 2. Single-column index — before/after on the same query
-- -------------------------------------------------------------
CREATE INDEX idx_student_name ON student(name);

-- Re-run the same query: type improves toward `ref`, key = idx_student_name, rows drops.
EXPLAIN SELECT * FROM student WHERE name = 'Grace Taylor';


-- -------------------------------------------------------------
-- 3. Unique indexes — constraints already build them
-- -------------------------------------------------------------
-- PRIMARY KEY and UNIQUE constraints appear here as indexes (Non_unique = 0).
-- `email` is already indexed by its UNIQUE constraint — no work needed.
SHOW INDEX FROM student;

-- A lookup on the already-unique email column: expect type = const.
EXPLAIN SELECT * FROM student WHERE email = 'grace.taylor@email.com';

-- Add a unique index where there is no constraint yet (also enforces uniqueness).
CREATE UNIQUE INDEX idx_course_name ON course(course_name);


-- -------------------------------------------------------------
-- 4. Composite index & the leftmost-prefix rule
-- -------------------------------------------------------------
CREATE INDEX idx_course_dept_credits ON course(department, credits);

-- Leading column → index applies.
EXPLAIN SELECT * FROM course WHERE department = 'Physics';

-- Both columns → index applies.
EXPLAIN SELECT * FROM course WHERE department = 'Computer Science' AND credits = 3;

-- Skips the leading column → index canNOT be used (possible_keys = NULL).
EXPLAIN SELECT * FROM course WHERE credits = 3;


-- -------------------------------------------------------------
-- 5. Covering index — answered from the index alone
-- -------------------------------------------------------------
-- All selected columns live in idx_course_dept_credits → Extra: Using index.
EXPLAIN SELECT department, credits FROM course WHERE department = 'Physics';

-- Add a column the index does not hold → must look up the row.
EXPLAIN SELECT department, credits, course_name FROM course WHERE department = 'Physics';


-- -------------------------------------------------------------
-- 6. What stops an index from being used (sargability)
-- -------------------------------------------------------------
CREATE INDEX idx_student_dob ON student(date_of_birth);

-- Function on the column → index unusable (full scan).
EXPLAIN SELECT * FROM student WHERE YEAR(date_of_birth) = 2001;

-- Rewritten as a range on the bare column → index can be used.
EXPLAIN SELECT * FROM student
WHERE date_of_birth >= '2001-01-01' AND date_of_birth < '2002-01-01';

-- Leading wildcard → index unusable.
EXPLAIN SELECT * FROM student WHERE name LIKE '%son';

-- Trailing wildcard → index CAN be used.
EXPLAIN SELECT * FROM student WHERE name LIKE 'Grace%';


-- -------------------------------------------------------------
-- 7. A deeper plan (optional) — JSON format with cost estimates
-- -------------------------------------------------------------
EXPLAIN FORMAT=JSON SELECT * FROM student WHERE name = 'Grace Taylor';


-- -------------------------------------------------------------
-- 8. Listing & dropping indexes
-- -------------------------------------------------------------
SHOW INDEX FROM course;


-- -------------------------------------------------------------
-- Cleanup — drop everything this script created (re-runnable)
-- -------------------------------------------------------------
DROP INDEX idx_student_name        ON student;
DROP INDEX idx_student_dob         ON student;
DROP INDEX idx_course_name         ON course;
DROP INDEX idx_course_dept_credits ON course;
