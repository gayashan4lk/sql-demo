-- =============================================================
-- 00 Joins — Runnable Examples
-- Run schema/reset.sql first. Assumes MySQL 8.0+.
-- These are all SELECTs — read-only, nothing to clean up.
-- Pair each block with the prose in lesson.md.
-- =============================================================


-- -------------------------------------------------------------
-- 0. The problem: enrollment stores ids, not names
-- -------------------------------------------------------------
SELECT * FROM enrollment LIMIT 2;


-- -------------------------------------------------------------
-- 2. INNER JOIN — student + enrollment, only matching rows
-- -------------------------------------------------------------
SELECT s.name, e.course_id, e.status
FROM student AS s
INNER JOIN enrollment AS e
    ON s.student_id = e.student_id;


-- -------------------------------------------------------------
-- 3. Three-table join through the enrollment junction
-- -------------------------------------------------------------
SELECT s.name, c.course_code, c.course_name, e.status
FROM student AS s
JOIN enrollment AS e ON s.student_id = e.student_id
JOIN course     AS c ON e.course_id  = c.course_id
ORDER BY s.name;


-- -------------------------------------------------------------
-- 4. LEFT JOIN — keep every enrollment, even ungraded ones (NULL grade)
-- -------------------------------------------------------------
SELECT e.enrollment_id, e.student_id, e.status, g.letter_grade, g.numeric_grade
FROM enrollment AS e
LEFT JOIN grade AS g
    ON g.enrollment_id = e.enrollment_id
ORDER BY e.enrollment_id;


-- -------------------------------------------------------------
-- 5. Anti-join — enrollments with NO grade yet (expect 14 rows)
-- -------------------------------------------------------------
SELECT e.enrollment_id, e.student_id, e.course_id, e.status
FROM enrollment AS e
LEFT JOIN grade AS g
    ON g.enrollment_id = e.enrollment_id
WHERE g.grade_id IS NULL;


-- -------------------------------------------------------------
-- 6. RIGHT JOIN — mirror of LEFT JOIN (these two return the same rows)
-- -------------------------------------------------------------
SELECT e.enrollment_id, g.letter_grade
FROM grade AS g
RIGHT JOIN enrollment AS e ON g.enrollment_id = e.enrollment_id;

SELECT e.enrollment_id, g.letter_grade
FROM enrollment AS e
LEFT JOIN grade AS g ON g.enrollment_id = e.enrollment_id;


-- -------------------------------------------------------------
-- 7. ON vs WHERE — the classic LEFT JOIN trap
-- -------------------------------------------------------------
-- Condition in WHERE: drops unmatched rows → behaves like an INNER JOIN
SELECT e.enrollment_id, g.letter_grade
FROM enrollment AS e
LEFT JOIN grade AS g ON g.enrollment_id = e.enrollment_id
WHERE g.letter_grade = 'A';

-- Condition in ON: keeps unmatched enrollments (NULL grade), restricts matches to 'A'
SELECT e.enrollment_id, g.letter_grade
FROM enrollment AS e
LEFT JOIN grade AS g
    ON g.enrollment_id = e.enrollment_id
   AND g.letter_grade = 'A';


-- -------------------------------------------------------------
-- 8. Joining + aggregating — enrollments vs graded per student
-- -------------------------------------------------------------
SELECT s.name,
       COUNT(e.enrollment_id) AS enrollments,
       COUNT(g.grade_id)      AS graded
FROM student AS s
JOIN      enrollment AS e ON e.student_id    = s.student_id
LEFT JOIN grade      AS g ON g.enrollment_id = e.enrollment_id
GROUP BY s.student_id, s.name
ORDER BY s.name;


-- -------------------------------------------------------------
-- 9. CROSS JOIN — every student paired with every course (99 rows)
-- -------------------------------------------------------------
SELECT s.name, c.course_code
FROM student AS s
CROSS JOIN course AS c;
