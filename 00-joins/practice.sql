-- =============================================================
-- 00 Joins — Practice Solutions
-- Run schema/reset.sql first. Assumes MySQL 8.0+.
-- All read-only SELECTs — nothing to clean up.
-- =============================================================


-- -------------------------------------------------------------
-- Problem 1 — Match Students to Their Enrollments (Easy)  [24 rows]
-- -------------------------------------------------------------
SELECT s.name, e.course_id, e.status
FROM student AS s
INNER JOIN enrollment AS e
    ON s.student_id = e.student_id
ORDER BY s.name;


-- -------------------------------------------------------------
-- Problem 2 — Add Course Names (Easy)  [24 rows]
-- -------------------------------------------------------------
SELECT s.name, c.course_code, c.course_name, e.status
FROM student AS s
JOIN enrollment AS e ON s.student_id = e.student_id
JOIN course     AS c ON e.course_id  = c.course_id
ORDER BY s.name, c.course_code;


-- -------------------------------------------------------------
-- Problem 3 — Keep Ungraded Enrollments (Medium)  [24 rows, 14 with NULL grade]
-- -------------------------------------------------------------
SELECT e.enrollment_id, e.student_id, e.status, g.letter_grade
FROM enrollment AS e
LEFT JOIN grade AS g
    ON g.enrollment_id = e.enrollment_id
ORDER BY e.enrollment_id;


-- -------------------------------------------------------------
-- Problem 4 — Find the Ungraded Enrollments (Medium)  [14 rows]
-- -------------------------------------------------------------
SELECT s.name, c.course_code, e.status
FROM enrollment AS e
JOIN      student AS s ON s.student_id = e.student_id
JOIN      course  AS c ON c.course_id  = e.course_id
LEFT JOIN grade   AS g ON g.enrollment_id = e.enrollment_id
WHERE g.grade_id IS NULL
ORDER BY s.name;


-- -------------------------------------------------------------
-- Problem 5 — Completed Courses with Grades (Hard)  [10 rows, 95.00 down to 65.00]
-- -------------------------------------------------------------
SELECT s.name, c.course_code, g.numeric_grade
FROM student AS s
JOIN enrollment AS e ON e.student_id    = s.student_id
JOIN course     AS c ON c.course_id     = e.course_id
JOIN grade      AS g ON g.enrollment_id = e.enrollment_id
WHERE e.status = 'Completed'
ORDER BY g.numeric_grade DESC;


-- -------------------------------------------------------------
-- Bonus — keep students with no Active enrollment (condition in ON, not WHERE)
-- -------------------------------------------------------------
SELECT s.name, e.course_id
FROM student AS s
LEFT JOIN enrollment AS e
    ON e.student_id = s.student_id
   AND e.status = 'Active'
ORDER BY s.name;
