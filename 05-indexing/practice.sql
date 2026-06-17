-- =============================================================
-- 05 Indexing — Practice Solutions
-- Run schema/reset.sql first. Assumes MySQL 8.0+.
-- Re-runnable: the Cleanup block at the end drops every index created here.
--
-- Reminder: on these tiny tables the optimiser may scan even with an index.
-- Judge each answer by whether the index appears in `possible_keys`.
-- =============================================================


-- -------------------------------------------------------------
-- Problem 1 — Index a Searched Column (Easy)
-- -------------------------------------------------------------
-- Before: full scan, no index applies
EXPLAIN SELECT * FROM student WHERE name = 'Henry Brown';

CREATE INDEX idx_student_name ON student(name);

-- After: idx_student_name now appears in possible_keys
EXPLAIN SELECT * FROM student WHERE name = 'Henry Brown';


-- -------------------------------------------------------------
-- Problem 2 — Discover Indexes You Already Have (Easy)
-- -------------------------------------------------------------
-- PRIMARY (student_id) and a UNIQUE index on email already exist (Non_unique = 0)
SHOW INDEX FROM student;

-- email is already indexed by its UNIQUE constraint → already fast
EXPLAIN SELECT * FROM student WHERE email = 'eva.martinez@email.com';

-- department has no constraint, so add a plain index
CREATE INDEX idx_course_department ON course(department);
EXPLAIN SELECT * FROM course WHERE department = 'Mathematics';


-- -------------------------------------------------------------
-- Problem 3 — Composite Index & Leftmost Prefix (Medium)
-- -------------------------------------------------------------
CREATE INDEX idx_course_dept_credits ON course(department, credits);

-- leading column → index applies
EXPLAIN SELECT * FROM course WHERE department = 'Computer Science';

-- both columns → index applies
EXPLAIN SELECT * FROM course WHERE department = 'Computer Science' AND credits = 3;

-- skips the leading column → possible_keys = NULL, full scan
EXPLAIN SELECT * FROM course WHERE credits = 3;


-- -------------------------------------------------------------
-- Problem 4 — Build a Covering Index (Medium)
-- -------------------------------------------------------------
-- idx_course_dept_credits from Problem 3 already covers (department, credits)

-- both selected columns are in the index → Extra: Using index
EXPLAIN SELECT department, credits FROM course WHERE department = 'English';

-- course_name is NOT in the index → row lookup, no longer covering
EXPLAIN SELECT department, credits, course_name FROM course WHERE department = 'English';


-- -------------------------------------------------------------
-- Problem 5 — Make a Query Sargable (Hard)
-- -------------------------------------------------------------
CREATE INDEX idx_student_dob ON student(date_of_birth);

-- function on the column → index unusable
EXPLAIN SELECT * FROM student WHERE YEAR(date_of_birth) = 2001;

-- range on the bare column → index can be used
EXPLAIN SELECT * FROM student
WHERE date_of_birth >= '2001-01-01' AND date_of_birth < '2002-01-01';

-- both return the same students (Alice Johnson, Eva Martinez, James Thomas)
SELECT name, date_of_birth FROM student WHERE YEAR(date_of_birth) = 2001;
SELECT name, date_of_birth FROM student
WHERE date_of_birth >= '2001-01-01' AND date_of_birth < '2002-01-01';


-- -------------------------------------------------------------
-- Cleanup — drop every index created above
-- -------------------------------------------------------------
DROP INDEX idx_student_name        ON student;
DROP INDEX idx_student_dob         ON student;
DROP INDEX idx_course_department   ON course;
DROP INDEX idx_course_dept_credits ON course;
