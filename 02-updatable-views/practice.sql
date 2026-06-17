-- Solution of Problem 1 — UPDATE Through a View (Easy)

CREATE VIEW student_names AS
SELECT student_id, name, gender
FROM student;

SELECT * FROM student_names;

UPDATE student_names
SET name = 'Robert Smith'
WHERE student_id = 2;

-- Solution of Problem 2 — DELETE Through a View (Easy)

CREATE OR REPLACE VIEW male_students_view AS
SELECT student_id, name, date_of_birth
FROM student
WHERE gender = 'Male';

SELECT * FROM male_students_view;

DELETE FROM male_students_view 
WHERE student_id = 4;

-- Solution of Problem 3 — WITH CHECK OPTION (Medium)

CREATE OR REPLACE VIEW young_students AS
SELECT student_id, name, date_of_birth
FROM student
WHERE date_of_birth > '2000-01-01'
WITH CHECK OPTION;

SELECT * FROM young_students;

UPDATE young_students
SET date_of_birth = '1995-05-01'
WHERE student_id = 3;

UPDATE young_students
SET date_of_birth = '2003-05-01'
WHERE student_id = 3;

-- Solution of Problem 4 — Spot the Updatable View (Hard / Conceptual)

-- View A: Updatable // simple select from a base table with where clause - each row maps to exactly one row in base table.
-- View B: Not updatable // uses GROUP BY and COUNT(*) - rows are aggregated, so rows aren't map to individual row in base table.
-- View C: Not updatable // uses DISTINCT - multiple rows in base table collapsed into on view row. So row in view is not maps to individual row in base table.
