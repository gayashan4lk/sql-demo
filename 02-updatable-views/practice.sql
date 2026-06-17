-- Solution of Problem 1 — UPDATE Through a View (Easy)

CREATE VIEW student_names AS
SELECT student_id, name, gender
FROM student;

SELECT * FROM student_names;

UPDATE student_names
SET name = 'Robert Smith'
WHERE student_id = 2;

SELECT * FROM student WHERE student_id = 2;

-- Solution of Problem 2 — DELETE Through a View (Easy)

CREATE OR REPLACE VIEW male_students_view AS
SELECT student_id, name, date_of_birth
FROM student
WHERE gender = 'Male';

SELECT * FROM male_students_view;

DELETE FROM male_students_view
WHERE student_id = 4;

SELECT * FROM student WHERE student_id = 4;

-- Solution of Problem 3 — WITH CHECK OPTION (Medium)

CREATE OR REPLACE VIEW young_students AS
SELECT student_id, name, date_of_birth
FROM student
WHERE date_of_birth > '2000-01-01'
WITH CHECK OPTION;

SELECT * FROM young_students;

-- Part A: This will FAIL
UPDATE young_students
SET date_of_birth = '1995-05-01'
WHERE student_id = 3;

-- Part B: This will SUCCEED
UPDATE young_students
SET date_of_birth = '2003-05-01'
WHERE student_id = 3;

-- Solution of Problem 4 — Spot the Updatable View (Hard / Conceptual)

-- View A: Updatable — simple select from a single table with WHERE clause.
-- View B: Not updatable — uses GROUP BY and COUNT(*), rows are aggregated.
-- View C: Not updatable — uses DISTINCT, multiple base rows collapse into one view row.

-- Solution of Problem 5 — Competing Date-Range Views (Hard)

CREATE VIEW pre_2001_students AS
SELECT student_id, name, date_of_birth
FROM student
WHERE date_of_birth <= '2000-12-31'
WITH CHECK OPTION;

CREATE VIEW post_2000_students AS
SELECT student_id, name, date_of_birth
FROM student
WHERE date_of_birth > '2000-12-31'
WITH CHECK OPTION;

SELECT * FROM pre_2001_students;
SELECT * FROM post_2000_students;

-- This will FAIL — CHECK OPTION prevents it
UPDATE post_2000_students
SET date_of_birth = '1999-06-01'
WHERE student_id = 1;

-- This SUCCEEDS — base table has no CHECK OPTION
UPDATE student
SET date_of_birth = '1999-06-01'
WHERE student_id = 1;

SELECT * FROM post_2000_students;
SELECT * FROM pre_2001_students;
